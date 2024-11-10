# frozen_string_literal: true

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

require_relative 'utils'

# Helper module to handle the practice
module PracticeService
  # Initializes the OpenAI client
  def client
    options = { access_token: ENV['TOKEN_OPENAI'], log_errors: true }
    @client ||= OpenAI::Client.new(**options)
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
end
