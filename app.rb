# Correr app: ruby app.rb
# http://127.0.0.1:3000/

require "sinatra"
require "sinatra/activerecord"
require "sinatra/cors"
require "sinatra/json"
require "byebug"
require "fileutils"
require "dotenv/load"
require "pdf-reader"
require "json"
require "openai"

require "./config/environment"

set :allow_origin, "http://127.0.0.1:3000"
set :port, 3000
enable :sessions

# Variable global a los metodos utilizada en POST Register para manejar errores
error_registration = ""

before do
  @isAnUserPresent = session[:isAnUserPresent] || false
end

get "/" do
  erb :index
end

get "/register" do
  erb :register
end

get "/login" do
  erb :login
end

get "/error-register" do
  case error_registration
  when "missing_fields"
    erb :error_missing_fields
  when "user_exists"
    erb :error_user_exists
  when "user_not_persisted"
    erb :error_registration_failed
  else
    redirect "/register"
  end
end

get "/logout" do
  session[:isAnUserPresent] = false
  redirect "/"
end

get "/practice" do
  redirect "/" unless session[:isAnUserPresent]
  erb :practice
end

post "/login" do
  if !session[:isAnUserPresent]
    username_or_email = params[:username_or_email]
    password = params[:password]

    if username_or_email && password
      @user = User.find_by(username: username_or_email, password: password) || User.find_by(email: username_or_email, password: password)
      if @user
        session[:isAnUserPresent] = true
        redirect "/"
      else
        @error = "No se encontró el usuario o el correo, o la contraseña es incorrecta!"
        erb :login
      end
    else
      @error = "Ingrese el nombre de usuario o correo electronico y la contraseña!"
      erb :login
    end
  else
    @error = "Para entrar en una cuenta primero se debe salir de la cuenta actual!"
    erb :login
  end
end

post "/register" do
  username = params[:username]
  name = params[:name]
  lastname = params[:lastname] || "Apellido No registrado"
  cellphone = params[:cellphone] || "Celular No registrado"
  email = params[:email]
  password = params[:password]

  if username.nil? || name.nil? || email.nil? || password.nil? || username.strip.empty? || name.strip.empty? || email.strip.empty? || password.strip.empty?
    error_registration = "missing_fields"
    redirect "/error-register"
    # Entra solamente por aca cuando se ponen espacios, porque el ".nil?" ya lo controla el form en el ERB con la clausula "required"
  else
    @user = User.find_by(username: username) || User.find_by(email: email)
    if @user
      error_registration = "user_exists"
      redirect "/error-register"
    else
      @user = User.create(username: username, name: name, lastname: lastname, cellphone: cellphone, email: email,
                          password: password)
      if @user.persisted?
        error_registration = ""
        session[:isAnUserPresent] = true
        redirect "/"
      else
        error_registration = "user_not_persisted"
        redirect "/error-register"
      end
    end
  end
end

post "/logout" do
  session[:isAnUserPresent] = false
  redirect "/"
end

post "/practice" do
  logger.info "Received request to generate quiz"
  logger.info "Params: #{params.inspect}"

  file = fetch_file(params)
  return file unless file.is_a?(Tempfile)

  full_text = extract_text_from_pdf(file)
  return json_error("Failed to extract text from PDF", 500) if full_text.empty?

  @questions = generate_questions(full_text)
  return json_error("Failed to generate quiz", 503) unless @questions

  session[:questions] = @questions # Guardamos las preguntas en la sesión
  session[:current_question_index] = 0 # Iniciamos en la primera pregunta
  session[:answered_questions] = [] # Inicializamos el array para las respuestas

  @current_question = @questions[session[:current_question_index]] # Mostramos la primera pregunta
  erb :question
end

post "/next_question" do
  @questions = session[:questions] # Recuperamos las preguntas de la sesión
  current_question_index = session[:current_question_index] # Recuperamos el índice

  if @questions.nil? || current_question_index.nil?
    @error = "No se encontraron preguntas o índice. Por favor, sube un PDF para generar el quiz."
    redirect "/practice"
  end

  selected_answer = params[:selected_option]
  correct_answer = @questions[current_question_index]["answer"] if @questions[current_question_index]

  if selected_answer == correct_answer
    @message = "¡Correcto!"
    @message_class = "correct"
  else
    @message = "Incorrecto. La respuesta correcta era: #{correct_answer}"
    @message_class = "incorrect"
  end

  # Guardamos la respuesta seleccionada en answered_questions
  session[:answered_questions] << selected_answer

  session[:current_question_index] += 1 # Avanza al siguiente índice
  @progress = (session[:current_question_index].to_f / @questions.size * 100).to_i # Calculamos el porcentaje

  if session[:current_question_index] < @questions.size
    @current_question = @questions[session[:current_question_index]]
    erb :question
  else
    # Contamos las respuestas correctas
    @correct_answers = session[:answered_questions].each_with_index.count do |answer, index|
      answer == @questions[index]["answer"]
    end
    @incorrect_answers = @questions.size - @correct_answers

    @message = "Has completado todas las preguntas."
    erb :quiz_complete
  end
end

# Initializes the OpenAI client
def client
  options = { access_token: ENV["TOKEN_OPENAI"], log_errors: true }
  @client ||= OpenAI::Client.new(**options)
end

# Fetches the file from a file upload
def fetch_file(params)
  if params[:file] && params[:file][:tempfile]
    logger.info "Successfully received file from tempfile"
    params[:file][:tempfile]
  else
    logger.error "No file provided"
    json_error("No file provided", 400)
  end
end

def generate_questions(full_text)
  prompt = <<-PROMPT
    Generate 10 insightful questions based on the following text. For each question, provide 4 multiple-choice options and indicate the correct answer.
    Please format each question as a JSON object within a list, with 'question', 'options' (a list of choices), and 'answer' (the correct choice) keys.
    Provide the response in Spanish.
  PROMPT

  response = client.chat(
    parameters: {
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: prompt },
        { role: "user", content: full_text },
      ],
      max_tokens: 3000,
      temperature: 0.5,
    },
  )

  # Ver que devolvio GPT por consola
  puts response.inspect

  parse_response(response)
rescue JSON::ParserError => e
  logger.error "Failed to parse JSON response: #{e.message}"
  nil
end

# Parses the response from the AI and extracts the questions
def parse_response(response)
  content = response.dig("choices", 0, "message", "content")
  content.gsub!(/^```json\n/, "").gsub!(/\n```$/, "")
  puts "Raw response: #{content}"
  JSON.parse(content)
rescue StandardError => e
  logger.error "Failed to parse AI response: #{e.message}"
  nil
end

# Extracts text from the provided PDF file
def extract_text_from_pdf(file)
  pdf = PDF::Reader.new(file)
  pdf.pages.map(&:text).join
rescue StandardError => e
  logger.error "Direct PDF text extraction failed: #{e.message}"
  ""
end

# Helper method for JSON error responses
def json_error(message, status_code)
  status status_code
  json error: message
end
