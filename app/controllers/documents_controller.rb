# frozen_string_literal: true

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/base'
require 'sinatra/cors'
require 'sinatra/json'
require 'byebug'
require 'fileutils'
require 'dotenv/load'
require 'pdf-reader'
require 'json'
require 'openai'
require 'digest'

require_relative '../models/document'

require_relative '../../helpers'

# Document controller
# It handles the documents views
class DocumentsController < Sinatra::Base
  helpers DocumentService
  helpers PracticeService
  helpers UserService
  helpers UtilsService
  enable :sessions

  before do
    session[:is_an_user_present] = session[:is_an_user_present] || false
    @is_an_user_present = session[:is_an_user_present] || false
  end

  # Ruta para mostrar todos los documentos
  get '/view_docs' do
    authenticate_user!
    if user
      @documents = Document.all
      status 210
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
    if params[:search] && !params[:search].empty?
      @documents = @documents.where('filename LIKE ?',
                                    "%#{params[:search]}%")
    end

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

  get '/documents/:id/statistics' do
    authenticate_user!
    @document = Document.find(params[:id])
    @questions = @document.questions
    erb :statistic
  end

  get '/error_document' do
    erb :error_document
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
end
