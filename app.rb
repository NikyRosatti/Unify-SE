# frozen_string_literal: true

# Correr app: ruby app.rb
# http://127.0.0.1:3000/

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/cors'
require 'sinatra/json'
require 'byebug'
require 'fileutils'
require 'dotenv/load'
require 'pdf-reader'
require 'json'
require 'openai'
require 'digest'

set :allow_origin, 'http://127.0.0.1:3000'
set :port, 3000
set :database_file, './config/database.yml'
Dir['./app/models/*.rb'].sort.each { |file| require file }

enable :sessions

before do
  @is_an_user_present = session[:is_an_user_present] || false
end

get '/' do
  erb :index
end

get '/register' do
  erb :register
end

get '/login' do
  erb :login
end

get '/error_register' do
  @err_register = session[:error_registration]
  session.delete(:error_registration)
  erb :error_registration_failed
end

get '/error_document' do
  erb :error_document
end

get '/logout' do
  session[:is_an_user_present] = false
  session[:admin_pw_verified] = false
  redirect '/'
end

get '/practice' do
  authenticate_user!
  erb :practice
end

get '/no_key_provided' do
  erb :no_key_provided
end

# Para ayudarnos y obtener la tabla general de progreso
get '/progress' do
  @users = User.all.order(correct_answers: :desc)
  erb :leaderboard
end

post '/login' do
  if session[:is_an_user_present]
    set_error_status(502, 'Para entrar en una cuenta primero se debe salir de la cuenta actual!')
  else
    username_or_email = params[:username_or_email].to_s.strip
    password = params[:password].to_s.strip

    if username_or_email.empty? || password.empty?
      set_error_status(501, 'Ingrese el nombre de usuario o correo electronico y la contraseña!')
    else
      user = find_user_by_credentials(username_or_email, password)
      puts "User found: #{user.inspect}"
      if user
        session[:is_an_user_present] = true
        session[:user_id] = user.id
        logger.info 'Sesion iniciada'
        redirect '/'
      else
        set_error_status(503, 'No se encontró el usuario o el correo, o la contraseña es incorrecta!')
      end
    end
  end
  erb :login
end

post '/register' do
  if fields_missing?(params)
    handle_error('missing_fields', 'Fields Username, Name, Email and Password must be filled out. Please try again.',
                 '/error-register')
  else
    user = find_user(params[:username], params[:email])
    if user
      handle_error('user_exists', 'An user with that username or email already exists. Please try a different one.',
                   '/error-register')
    else
      register_user(params)
    end
  end
end

post '/logout' do
  session[:is_an_user_present] = false
  session[:user_id] = nil
  redirect '/'
end

post '/practice' do
  # logger.info 'Received request to generate quiz'
  # logger.info "Params: #{params.inspect}"

  file = fetch_file(params)
  return file unless file.is_a?(Tempfile)

  response_save_pdf = save_pdf(params)
  return json_error(response_save_pdf[1], response_save_pdf[0]) unless response_save_pdf[0] == 201

  full_text = extract_text_from_pdf(file)
  return json_error('Failed to extract text from PDF', 500) if full_text.empty?

  document = response_save_pdf[2] # Rescato el documento de la base de datos para pasarla al metodo

  # Verifica si ya hay preguntas asociadas al documento
  if Question.where(document: document).exists?
    redirect "/documents/#{document.id}/practice_doc"
  else
    @questions = generate_questions(full_text)
    return json_error('Failed to generate quiz', 503) unless @questions
  end

  puts '<!-- Starting Saving Questions -->'
  save_questions_to_db(@questions, document)
  @document = document
  puts '<!-- End Saving Questions -->'

  status 251 # Llegar de manera adecuada y mostrar el cuestionario
  logger.info 'Correcta verificacion de metodos'
  session[:document_id] = @document.id
  puts "Document ID: #{session[:document_id]}"

  session[:current_question_index] = 0 # Iniciamos en la primera pregunta
  session[:answered_questions] = [] # Inicializamos el array para las respuestas

  @current_question = Question.where(document: session[:document_id]).first # Mostramos la primera pregunta

  erb :question
end

post '/next_question' do
  document_id = session[:document_id]
  current_question_index = session[:current_question_index]

  # Guarda las preguntas correspondientes al documento almacenado en la base de datos
  questions = Question.where(document_id: document_id).order(:id)

  if questions.nil? || current_question_index.nil?
    @error = 'No se encontraron preguntas o índice. Por favor, sube un PDF para generar el quiz.'
    redirect '/practice'
  end

  selected_answer = params[:selected_option]
  @current_question = questions.offset(current_question_index).first # Obtiene la pregunta actual

  process_answer(selected_answer)

  session[:current_question_index] += 1 # Avanza al siguiente índice
  logger.debug "Current question index: #{session[:current_question_index]}"

  @progress = (session[:current_question_index].to_f / questions.size * 100).to_i # Calculamos el porcentaje

  if session[:current_question_index] < questions.size
    @current_question = questions.offset(session[:current_question_index]).first  # Obtiene la siguiente pregunta
    erb :question
  else
    complete_quiz(questions)
  end
end

get '/give_me_admin_please' do
  authenticate_user!
  @already_admin = User.find(session[:user_id]).is_admin
  erb :admin_view
end

post '/verify_admin_password' do
  authenticate_user!
  ultra_secret_admin_password =
    'You->ShouldCopy()ThisString$$InOrderToBeARealAdmin,,,Otherwise~YouWillGetConfused!!And&WontBeAbleToBeAnAdmin!!'

  if params[:entered_pw] == ultra_secret_admin_password
    session[:admin_pw_verified] = true
    redirect '/give_me_admin_please'
  else
    session[:admin_pw_verified] = false
    redirect '/give_me_admin_please?error=invalid_password'
  end
end

post '/give_me_admin_please' do
  if user && session[:admin_pw_verified]
    user.update(is_admin: 1)
    session[:admin_pw_verified] = false
    redirect '/give_me_admin_please'
  else
    logger.error('No se encontro el usuario: fallo la busqueda en la base de datos segun session[:user_id]')
    redirect '/give_me_admin_please?error=unauthorized_access'
  end
end

post '/remove_me_from_admins_please' do
  if user
    user.update(is_admin: 0)
  else
    logger.error('No se encontro el usuario: fallo la busqueda en la base de datos segun session[:user_id]')
  end
  redirect '/give_me_admin_please'
end

# Ruta para mostrar todos los documentos
get '/view_docs' do
  authenticate_user!
  if user
    @documents = Document.all
    erb :view_docs
  else
    erb :status404
  end
end

post '/view_docs' do
  @documents = Document.all

  # Ordenar por nombre alfabéticamente
  case params[:sort]
  when 'name'
    @documents = @documents.order('filename ASC')
  when 'recent'
    # Ordenar por fecha de carga (más recientes primero)
    @documents = @documents.order('created_at DESC')
  when 'oldest'
    # Ordenar por fecha de carga (más antiguos primero)
    @documents = @documents.order('created_at ASC')
  end

  # Filtrar por nombre si se proporcionó un término de búsqueda
  @documents = @documents.where('filename LIKE ?', "%#{params[:search]}%") if params[:search] && !params[:search].empty?

  # Renderizar la vista de documentos
  erb :view_docs
end

# Ruta para mostrar un documento específico
get '/documents/:id' do
  authenticate_user!
  @document = Document.find(params[:id])
  @questions = @document.questions
  erb :view_doc
end

get '/documents/:id/practice_doc' do
  authenticate_user!
  document_id = params[:id] # El ID del documento que el usuario selecciona
  @document = Document.find(document_id)

  if @document.nil?
    @error = 'No hay preguntas disponibles para este documento.'
    redirect '/'
  end

  session[:document_id] = document_id
  session[:current_question_index] = 0 # Iniciar en la primera pregunta
  session[:answered_questions] = [] # Inicializar respuestas contestadas

  @current_question = Question.where(document: session[:document_id]).first # Mostramos la primera pregunta

  if @current_question.nil?
    @error = 'No se encontraron preguntas para este documento.'
    redirect '/'
  else
    erb :question
  end
end

get '/documents/:id/statistics' do
  authenticate_user!
  @document = Document.find(params[:id])
  @questions = @document.questions
  erb :statistic
end

get '/question_statistics' do
  authenticate_user!
  if user.is_admin?
    # Tipo de filtro a aplicar
    filter = params[:filter]

    @top_correct_questions = Question.order(correct_answers_cant: :desc).limit(10)
    @top_incorrect_questions = Question.select('questions.* ,
    (number_answers_answered - correct_answers_cant) AS incorrect_answers')
                                       .order('incorrect_answers DESC')
                                       .limit(10)

    if filter == 'correct'
      @top_questions = @top_correct_questions
      @title = 'Top 10 Questions Answered Correctly'
    else
      @top_questions = @top_incorrect_questions
      @title = 'Top 10 Questions Answered Incorrectly'
    end
    erb :question_statistics
  else
    halt 404, 'Access denied due to user level.'
    # redirect "/"
  end
end

post '/documents/:id/favorite' do
  document = Document.find(params[:id])

  user.favorite_documents << document
  status 200 # Éxito
end

delete '/documents/:id/unfavorite' do
  document = Document.find(params[:id])

  if user.favorite_documents.include?(document)
    user.favorite_documents.delete(document) # Elimina el documento de los favoritos
    status 200 # Respuesta 200 OK si se elimina correctamente
  else
    erb :status404
  end

  redirect '/favorites'
end

delete '/settings/:id' do
  if user&.destroy
    session.clear
    redirect '/logout'
  else
    redirect '/settings'
  end
end

delete '/api/documents/:id' do
  document = Document.find(params[:id])

  # Encuentra el documento por su ID y lo elimina
  if document
    # Eliminar las tablas relacionadas, si existen

    # Primero, elimina los favoritos del documento
    document.favorites.destroy_all

    # Iterar sobre cada pregunta del documento
    document.questions.each do |question|
      # Para cada opción de la pregunta, elimina su respuesta
      question.answer.destroy # Elimina la respuestas asociada a la pregunta
      question.options.destroy_all # Eliminar todas las opciones asociadas a la pregunta
    end

    # Por ultimo, elimina las preguntas del documento
    document.questions.destroy_all

    document.destroy
    status 200
    { message: 'Documento eliminado correctamente' }.to_json
  else
    status 404
    { message: 'Documento no encontrado' }.to_json
  end
end

get '/favorites' do
  authenticate_user!
  if user
    @favorites = user.favorites.map(&:document)
    erb :favorites
  else
    erb :status404
  end
end

get '/settings' do
  if user
    rank
    erb :account_settings
  else
    erb :status404
  end
end

get '/privacy' do
  erb :privacy
end

private

# Initializes the OpenAI client
def client
  options = { access_token: ENV['TOKEN_OPENAI'], log_errors: true }
  @client ||= OpenAI::Client.new(**options)
end

# Fetches the file from a file upload
def fetch_file(params)
  if params[:file] && params[:file][:tempfile]
    logger.info 'Successfully received file from tempfile'
    params[:file][:tempfile]
  else
    status 510
    logger.error 'No file provided'
    @no_file_provided = 'No file provided'
    erb :practice
  end
end

def save_pdf(params) # rubocop:disable Metrics/MethodLength
  # Este metodo devuelve un arreglo con 3 cosas:
  # save_pdf[0] == Status Code HTTP segun guardado o no
  # save_pdf[1] == Mensaje JSON segun Status Code Error
  # save_pdf[2] == El documento que se guarda en la base de datos o nil en caso contrario

  return [400, 'No se proporcionó un archivo', nil] unless file_provided?(params)

  file = params[:file][:tempfile]
  filename = params[:file][:filename].force_encoding('UTF-8')
  filecontent = file.read

  # Chequeo si el archivo ya existe
  file_hash = Digest::SHA256.hexdigest(filecontent)
  existent_document = Document.find_by(file_hash: file_hash)
  return [201, 'El PDF a guardar ya existe en la base de datos', existent_document] if existent_document

  return redirect '/error_document' unless File.extname(filename) == '.pdf'

  document = save_new_document(filename, filecontent, file_hash)

  return [201, 'PDF guardado correctamente', document] if document.persisted?

  # Error en la persistencia
  [500, 'Error al guardar el archivo PDF en la base de datos', nil]
end

def file_provided?(params)
  params[:file] && params[:file][:tempfile]
end

def save_new_document(filename, filecontent, file_hash)
  Document.create(
    filename: filename,
    filecontent: filecontent,
    file_hash: file_hash,
    uploaddate: Date.today
  )
end

def save_questions_to_db(questions_json, document)
  # Entra como parametro un JSON dado por GPT y el documento que se esta trabajando
  # Para cada elemento del hash (question, options, answer)
  questions_json.each do |question_data|
    # Proceso los elementos "question", creandolos en la base de datos
    # Asocia el contenido de la pregunta a content y a qué documento pertenece
    question = Question.create(content: question_data['question'], document: document)
    # Proceso los elementos "options"
    puts '<!-- 2 Starting saving options -->'
    save_options_to_db(question, question_data['options'])
    puts '<!-- 2 Ending saving options -->'
    # Proceso los elementos "answer"
    puts '<!-- 3 Starting saving answer -->'
    save_answer_to_db(question, question_data['answer'])
    puts '<!-- 3 Ending saving answer -->'
  end
end

def save_options_to_db(question, options)
  options.each do |option_content|
    # Crea la opción asociada a la pregunta
    Option.create(content: option_content, question: question)
  end
end

def save_answer_to_db(question, correct_answer)
  # Busca la opción correcta en el conjunto de opciones
  correct_option = Option.find_by(content: correct_answer, question: question)

  # Crea la respuesta correcta de la pregunta según las opciones de ella
  Answer.create(question: question, option: correct_option)
end

def generate_questions(full_text) # rubocop:disable Metrics/MethodLength
  prompt = <<-PROMPT
    Generate 10 insightful questions based on the following text. For each question, provide 4 multiple-choice options and indicate the correct answer.
    Please format each question as a JSON object within a list, with 'question', 'options' (a list of choices), and 'answer' (the correct choice) keys.
    Ensure that no unusual Unicode symbols are used in the questions or answers. Use only common programming symbols and ASCII characters.
    Provide the response in Spanish.
  PROMPT

  begin
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: prompt },
          { role: 'user', content: full_text }
        ],
        max_tokens: 3000,
        temperature: 0.5
      }
    )
  rescue Faraday::UnauthorizedError => e
    logger.error "Unauthorized access - API Key may be incorrect: #{e.message}"
    redirect '/no-key-provided'
  end
  # Ver que devolvio GPT por consola
  # puts response.inspect

  parse_response(response)
rescue JSON::ParserError => e
  logger.error "Failed to parse JSON response: #{e.message}"
  nil
end

# Parses the response from the AI and extracts the questions
def parse_response(response)
  content = response.dig('choices', 0, 'message', 'content')
  content = content.force_encoding('UTF-8')
  content.gsub!(/^```json\n/, '').gsub!(/\n```$/, '')
  puts "Raw response: #{content}"
  puts 'End Raw response'
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
  ''
end

# Helper method for JSON error responses
def json_error(message, status_code)
  status status_code
  json error: message
end

def set_error_status(status_code, error_message)
  status status_code
  @error = error_message
  logger.error @error
end

def find_user_by_credentials(username_or_email, password)
  User.find_by(username: username_or_email, password: password) ||
    User.find_by(email: username_or_email, password: password)
end

def fields_missing?(params)
  required_fields = %i[username name email password]
  required_fields.any? { |field| params[field].to_s.strip.empty? }
end

def find_user(username, email)
  User.find_by(username: username.to_s.strip) || User.find_by(email: email.to_s.strip)
end

def handle_error(error_key, error_message, redirect_path)
  session[:error_registration] = error_key
  logger.error error_message
  redirect redirect_path
end

def register_user(params)
  b_day = params[:b_day].presence ? Date.parse(params[:b_day]) : nil
  gender = params[:gender].presence

  user = build_user(params, b_day, gender)

  if user.persisted?
    handle_successful_registration(user)
  else
    handle_error_registration
  end
end

def build_user(params, b_day, gender)
  User.create(
    username: clean_param(params[:username]),
    name: clean_param(params[:name]),
    lastname: clean_or_default(params[:lastname], 'ApellidoNoRegistrado'),
    cellphone: clean_or_default(params[:cellphone], 'CelularNoRegistrado'),
    email: clean_param(params[:email]),
    password: clean_param(params[:password]),
    b_day: b_day, gender: gender,
    is_admin: 0
  )
end

def clean_param(param)
  param.to_s.strip
end

def clean_or_default(param, default)
  param.to_s.strip.empty? ? default : param.to_s.strip
end

def handle_successful_registration(user)
  session[:is_an_user_present] = true
  session.delete(:error_registration)
  session[:user_id] = user.id
  redirect '/'
end

def handle_error_registration
  handle_error('user_not_persisted', 'There was a problem registering your account. Please try again later.',
               '/error-register')
end

def process_answer(selected_answer) # rubocop:disable Metrics/MethodLength
  logger.debug "Loaded question: #{@current_question.content}" if @current_question
  correct_answer = @current_question.answer.option.content # Accedemos al contenido de la pregunta y no al objeto

  if selected_answer == correct_answer
    @message = '¡Correcto!'
    @message_class = 'correct'

    @current_question.increment!(:correct_answers_cant) # Incrementamos el atributo
  else
    @message = "Incorrecto. La respuesta correcta era: #{correct_answer}"
    @message_class = 'incorrect'
  end

  # Incrementamos el número total de respuestas a la pregunta
  @current_question.increment!(:number_answers_answered)

  # Guardamos la respuesta seleccionada en answered_questions
  session[:answered_questions] << selected_answer
end

def complete_quiz(questions)
  # Contamos las respuestas correctas
  @correct_answers = session[:answered_questions].each_with_index.count do |answer, index|
    answer == questions[index].answer.option.content
  end

  @incorrect_answers = questions.size - @correct_answers

  user&.increment!(:correct_answers, @correct_answers)

  @message = 'Has completado todas las preguntas.'
  erb :quiz_complete
end

def rank
  # Obtener la posición del usuario en base a las respuestas correctas
  user_ranks =  User
                .select('users.*, correct_answers')
                .order('correct_answers DESC')

  # Convertir a un hash para un acceso más fácil
  user_position = user_ranks.map(&:id)

  # Encontrar la posición del usuario específico
  @position = user_position.index(user.id) + 1 # +1 porque empieza de 0
end

helpers do
  def user
    @user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    redirect '/' unless session[:is_an_user_present]
  end

  def csrf_token
    session[:csrf] ||= SecureRandom.hex(32)
  end
end
