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

  def save_pdf(params)
    # Este metodo devuelve un arreglo con 3 cosas:
    # save_pdf[0] == Status Code HTTP segun guardado o no
    # save_pdf[1] == Mensaje JSON segun Status Code Error
    # save_pdf[2] == El documento que se guarda en la base de datos o nil en caso contrario

    handle_file_provided(params)

    file = params[:file][:tempfile]
    filename = params[:file][:filename].force_encoding('UTF-8')
    handle_long_filename(filename)
    handle_invalid_format(filename)

    file_hash, filecontent = read_and_hash(file)

    response_existent = handle_existing_file(file_hash)
    return response_existent if response_existent

    document = save_new_document(filename, filecontent, file_hash)
    handle_document_persisted(document)
  end

  def handle_file_provided(params)
    [400, 'No se proporcionó un archivo', nil] unless params[:file] && params[:file][:tempfile]
  end

  def handle_long_filename(filename)
    return unless filename.length > 25

    session[:why] = 'The filename is too long'
    redirect '/error_document'
  end

  def handle_invalid_format(filename)
    return if File.extname(filename) == '.pdf'

    session[:why] = 'Document is not a PDF'
    redirect '/error_document'
  end

  def read_and_hash(file)
    filecontent = file.read
    [Digest::SHA256.hexdigest(filecontent), filecontent]
  end

  def handle_existing_file(file_hash)
    existent_document = Document.find_by(file_hash: file_hash)
    [201, 'El PDF a guardar ya existe en la base de datos', existent_document] if existent_document
  end

  def handle_document_persisted(document)
    if document.persisted?
      [202, 'PDF guardado correctamente', document]
    else
      [500, 'Error al guardar el archivo PDF en la base de datos', nil]
    end
  end
end
