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

require_relative '../app/models/answer'
require_relative '../app/models/document'
require_relative '../app/models/option'
require_relative '../app/models/question'

# Helper module to handle documents methods
module DocumentService
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

  # Extracts text from the provided PDF file
  def extract_text_from_pdf(file)
    pdf = PDF::Reader.new(file)
    pdf.pages.map(&:text).join
  rescue StandardError => e
    logger.error "Direct PDF text extraction failed: #{e.message}"
    ''
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

    if filename.length > 15
      session[:why] = 'The filename is too long'
      return redirect '/error_document'
    end

    # Chequeo si el archivo ya existe
    file_hash = Digest::SHA256.hexdigest(filecontent)
    existent_document = Document.find_by(file_hash: file_hash)
    return [201, 'El PDF a guardar ya existe en la base de datos', existent_document] if existent_document

    unless File.extname(filename) == '.pdf'
      session[:why] = 'Document is not a PDF'
      return redirect '/error_document'
    end

    document = save_new_document(filename, filecontent, file_hash)

    return [202, 'PDF guardado correctamente', document] if document.persisted?

    # Error en la persistencia
    [500, 'Error al guardar el archivo PDF en la base de datos', nil]
  end

  def file_provided?(params)
    params[:file] && params[:file][:tempfile]
  end
end
