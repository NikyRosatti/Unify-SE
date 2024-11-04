# frozen_string_literal: true

# Correr app: ruby app.rb
# http://127.0.0.1:3000/

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
require_relative '../models/user'

require_relative '../../helpers'

# User controller
# It handles all the users relationated views
class UsersController < Sinatra::Base
  helpers DocumentService
  helpers PracticeService
  helpers UserService
  helpers UtilsService
  enable :sessions

  before do
    session[:is_an_user_present] = session[:is_an_user_present] || false
    @is_an_user_present = session[:is_an_user_present] || false
  end

  get '/register' do
    erb :register
  end

  get '/error_register' do
    @err_register = session[:error_registration]
    session.delete(:error_registration)
    erb :error_registration_failed
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    login_while_user_present?
    login_missing_fields?
    login_successfully?(params[:username_or_email].to_s.strip, params[:password].to_s.strip)
    login_incorrect
  end

  post '/register' do
    fields_missing?(params)
    existent_user?(params)
    register_user(params)
  end

  post '/logout' do
    session[:is_an_user_present] = false
    session[:user_id] = nil
    redirect '/'
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

    unless params[:entered_pw] == ultra_secret_admin_password
      session[:admin_pw_verified] = false
      redirect '/give_me_admin_please?error=invalid_password'
    end
    session[:admin_pw_verified] = true
    redirect '/give_me_admin_please'
  end

  post '/give_me_admin_please' do
    unless user && session[:admin_pw_verified]
      logger.error('No se encontro el usuario: fallo la busqueda en la base de datos segun session[:user_id]')
      redirect '/give_me_admin_please?error=unauthorized_access'
    end
    user.update(is_admin: 1)
    session[:admin_pw_verified] = false
    redirect '/give_me_admin_please'
  end

  post '/remove_me_from_admins_please' do
    if user
      user.update(is_admin: 0)
    else
      logger.error('No se encontro el usuario: fallo la busqueda en la base de datos segun session[:user_id]')
    end
    redirect '/give_me_admin_please'
  end

  get '/logout' do
    session[:is_an_user_present] = false
    session[:admin_pw_verified] = false
    redirect '/'
  end

  get '/favorites' do
    authenticate_user!
    erb :status404 unless user && !Document.count.zero?
    @favorites = user.favorites.map(&:document)
    erb :favorites
  end

  post '/documents/:id/favorite' do
    document = Document.find(params[:id])
    user.favorite_documents << document
    status 200 # Éxito
  end

  delete '/documents/:id/unfavorite' do
    document = Document.find(params[:id])
    erb :status404 unless user.favorite_documents.include?(document)
    user.favorite_documents.delete(document) # Elimina el documento de los favoritos
    status 200 # Respuesta 200 OK si se elimina correctamente
    redirect '/favorites'
  end
end
