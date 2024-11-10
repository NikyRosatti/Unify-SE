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

ENV['APP_ENV'] = 'test'

require_relative '../app'
require 'spec_helper'
require 'rack/test'
require 'rspec'

describe 'POST /practice' do
  context 'cuando se sube un PDF válido' do
    it 'recibe como ultimo status 251 por haber creado el cuestionario' do
      # Crea un usuario de prueba y simula el inicio de sesión
      User.create(username: 'testuser', password: 'password')
      post '/login', { username_or_email: 'testuser', password: 'password' }

      # Simula la subida de un archivo PDF
      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), 'fixtures/sample.pdf'),
                                              'application/pdf')
      post '/practice', { file: pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_response.status).to eq(251)
    end
  end

  context 'cuando no se proporciona un archivo' do
    it 'recibe como ultimo status 510 y que la ultima respuesta sea un mensaje de error' do
      post '/practice', { file: nil }, 'rack.session' => { is_an_user_present: true }

      expect(last_response.status).to eq(510)
      expect(last_response.body).to include('No file provided')
    end
  end

  context 'cuando se sube un PDF que no se puede procesar' do
    it 'recibe como ultimo status 500 y que la ultima respuesta sea un mensaje de error' do
      # Crea un usuario de prueba y simula el inicio de sesión
      User.create(username: 'testuser', password: 'password')
      post '/login', { username_or_email: 'testuser', password: 'password' }

      # Simula la subida de un archivo PDF no válido
      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), 'fixtures/invalid_sample.pdf'),
                                              'application/pdf')
      post '/practice', { file: pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Failed to extract text from PDF')
    end
  end

  context 'cuando se sube un archivo que no es un PDF' do
    it 'redirecciona a /error_document' do
      User.create(username: 'testuser', password: 'password')
      post '/login', { username_or_email: 'testuser', password: 'password' }

      non_pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), 'fixtures/not_a_pdf.txt'),
                                                  'text/plain')
      post '/practice', { file: non_pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.path).to eq('/error_document')
    end
  end

  context 'cuando el PDF ya existe en la base de datos' do
    it 'devuelve status 201 y un mensaje de que el PDF ya existe en la base de datos' do
      # Crea un usuario de prueba y simula el inicio de sesión
      User.create(username: 'testuser', password: 'password')
      post '/login', { username_or_email: 'testuser', password: 'password' }

      # Carga el archivo sample.pdf de la carpeta fixtures
      pdf_path = File.join(File.dirname(__FILE__), 'fixtures/sample.pdf')
      pdf_file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
      file_content = File.read(pdf_path)

      # Calcula el hash del contenido del archivo y guarda el documento en la base de datos
      file_hash = Digest::SHA256.hexdigest(file_content)
      Document.create(
        filename: 'sample.pdf',
        filecontent: file_content,
        file_hash: file_hash,
        uploaddate: Date.today
      )

      post '/practice', { file: pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_response.status).to eq(302)
    end
  end

  context 'cuando ocurre un error al guardar el documento en la base de datos' do
    it 'devuelve un estado 500 y un mensaje de error' do
      allow(Document).to receive(:create).and_return(double('Document', persisted?: false))

      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), 'fixtures/sample.pdf'),
                                              'application/pdf')
      post '/practice', { file: pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('Error saving the PDF file to the database')
    end
  end

  context 'cuando se carga correctamente el cuestionario' do
    it 'inicializa las variables de sesión correctamente' do
      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), 'fixtures/sample.pdf'), 'application/pdf')
      allow_any_instance_of(PracticeController).to receive(:generate_questions).and_return([{ 
        'question' => 'Sample Question?',
        'options' => ['Option 1'],
        'answer' => 'Option 1' 
      }])

      post '/practice', { file: pdf_file }, 'rack.session' => { is_an_user_present: true }

      expect(last_request.env['rack.session'][:document_id]).not_to be_nil
      expect(last_request.env['rack.session'][:current_question_index]).to eq(0)
      expect(last_request.env['rack.session'][:answered_questions]).to eq([])
    end
  end

  context 'cuando se avanza a la siguiente pregunta' do
    it 'incrementa el índice de la pregunta y muestra la siguiente pregunta' do
      document = Document.create(filename: 'test.pdf', filecontent: 'PDF content', file_hash: 'hash')
      question1 = Question.create(content: 'Pregunta 1', document: document)
      option1 = Option.create(content: 'Opcion 1 pregunta 1', question_id: question1.id, created_at: Date.today,
                              updated_at: Date.today)
      Answer.create(question_id: question1.id, option_id: option1.id, created_at: Date.today,
                    updated_at: Date.today)

      question2 = Question.create(content: 'Pregunta 2', document: document)
      option2 = Option.create(content: 'Opcion 1 pregunta 2', question_id: question1.id, created_at: Date.today,
                              updated_at: Date.today)
      Answer.create(question_id: question2.id, option_id: option2.id, created_at: Date.today,
                    updated_at: Date.today)

      session_data = {
        document_id: document.id,
        current_question_index: 0,
        answered_questions: []
      }

      post '/next_question', { selected_option: 'Opcion 1 pregunta 1' }, 'rack.session' => session_data

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Pregunta 2')
    end
  end

  context 'cuando el usuario selecciona la respuesta correcta' do
    it 'muestra el mensaje de éxito y actualiza el contador de respuestas correctas' do
      document = Document.create(filename: 'test.pdf', filecontent: 'PDF content', file_hash: 'hash')
      question1 = Question.create(content: 'Pregunta 1', document: document)
      option1 = Option.create(content: 'Opcion correcta', question_id: question1.id, created_at: Date.today,
                              updated_at: Date.today)
      Answer.create(question_id: question1.id, option_id: option1.id, created_at: Date.today,
                    updated_at: Date.today)

      question2 = Question.create(content: 'Pregunta 2', document: document)
      option2 = Option.create(content: 'Opcion 1 pregunta 2', question_id: question1.id, created_at: Date.today,
                              updated_at: Date.today)
      Answer.create(question_id: question2.id, option_id: option2.id, created_at: Date.today,
                    updated_at: Date.today)

      session_data = {
        document_id: document.id,
        current_question_index: 0,
        answered_questions: []
      }

      post '/next_question', { selected_option: 'Opcion correcta' }, 'rack.session' => session_data

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Correct!')
    end
  end

  context 'cuando el usuario selecciona una respuesta incorrecta' do
    it 'muestra el mensaje de error y la respuesta correcta' do
      document = Document.create(filename: 'test.pdf', filecontent: 'PDF content', file_hash: 'hash')
      question1 = Question.create(content: 'Pregunta 1', document: document)
      option1 = Option.create(content: 'Opcion correcta', question_id: question1.id, created_at: Date.today,
                              updated_at: Date.today)
      Option.create(content: 'Opcion incorrecta', question_id: question1.id, created_at: Date.today,
                    updated_at: Date.today)
      Answer.create(question_id: question1.id, option_id: option1.id, created_at: Date.today,
                    updated_at: Date.today)

      question2 = Question.create(content: 'Pregunta 2', document: document)
      option2 = Option.create(content: 'Opcion 1 pregunta 2', question_id: question2.id, created_at: Date.today,
                              updated_at: Date.today)
      Answer.create(question_id: question2.id, option_id: option2.id, created_at: Date.today,
                    updated_at: Date.today)

      session_data = {
        document_id: document.id,
        current_question_index: 0,
        answered_questions: []
      }

      post '/next_question', { selected_option: 'Opcion incorrecta' }, 'rack.session' => session_data

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Incorrect. The correct answer was: #{option1.content}")
    end
  end

  context 'cuando el usuario completa todas las preguntas' do
    it 'muestra el mensaje de finalización del cuestionario' do
      document = Document.create(filename: 'test.pdf', filecontent: 'PDF content', file_hash: 'hash')
      question = Question.create(content: 'Pregunta 1', document: document)
      option = Option.create(content: 'Respuesta correcta', question: question)
      Answer.create(option: option)

      session_data = {
        document_id: document.id,
        current_question_index: 1, # Supone que esta es la última pregunta
        answered_questions: ['Respuesta correcta']
      }

      post '/next_question', { selected_option: 'Respuesta correcta' }, 'rack.session' => session_data

      expect(last_response.body).to include('You have completed all the questions.')
    end
  end

  context 'cuando no hay preguntas o el índice es nulo' do
    it 'redirecciona a /practice con status 302' do
      session_data = {
        document_id: nil,
        current_question_index: nil,
        answered_questions: []
      }

      post '/next_question', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/practice')
    end
  end
end
