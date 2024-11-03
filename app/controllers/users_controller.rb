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

require_relative '../services/user_services'
require_relative '../services/utils'

enable :sessions

class UsersController < Sinatra::Base
  def initialize(*args)
    super(*args)
    @utils_service = UtilsService.new(self)
    @user_service = UserService.new(self)
  end
  # before do
  #   @utils_service = UtilsService.new
  # end

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
    if session[:is_an_user_present]
      @utils_service.set_error_status(502, 'Para entrar en una cuenta primero se debe salir de la cuenta actual!')
    else
      username_or_email = params[:username_or_email].to_s.strip
      password = params[:password].to_s.strip

      if username_or_email.empty? || password.empty?
        @utils_service.set_error_status(501, 'Ingrese el nombre de usuario o correo electronico y la contraseña!')
      else
        user = @user_service.find_user_by_credentials(username_or_email, password)
        puts "User found: #{user.inspect}"
        if user
          session[:is_an_user_present] = true
          session[:user_id] = user.id
          logger.info 'Sesion iniciada'
          redirect '/'
        else
          @utils_service.set_error_status(503, 'No se encontró el usuario o el correo, o la contraseña es incorrecta!')
        end
      end
    end
    erb :login
  end

  post '/register' do
    if @user_service.fields_missing?(params)
      @utils_service.handle_error('missing_fields',
                                  'Fields Username, Name, Email and Password must be filled out. Please try again.',
                                  '/error_register')
    else
      user = @user_service.find_user(params[:username], params[:email])
      if user
        @utils_service.handle_error('user_exists',
                                    'An user with that username or email already exists. Please try a different one.',
                                    '/error_register')
      else
        @user_service.register_user(params)
      end
    end
  end

  post '/logout' do
    session[:is_an_user_present] = false
    session[:user_id] = nil
    redirect '/'
  end

  get '/give_me_admin_please' do
    @utils_service.authenticate_user!
    @already_admin = User.find(session[:user_id]).is_admin
    erb :admin_view
  end

  post '/verify_admin_password' do
    @utils_service.authenticate_user!
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
    if @utils_service.user && session[:admin_pw_verified]
      @utils_service.user.update(is_admin: 1)
      session[:admin_pw_verified] = false
      redirect '/give_me_admin_please'
    else
      logger.error('No se encontro el usuario: fallo la busqueda en la base de datos segun session[:user_id]')
      redirect '/give_me_admin_please?error=unauthorized_access'
    end
  end

  post '/remove_me_from_admins_please' do
    if @utils_service.user
      @utils_service.user.update(is_admin: 0)
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
    @utils_service.authenticate_user!
    if @utils_service.user
      @favorites = @utils_service.user.favorites.map(&:document)
      erb :favorites
    else
      erb :status404
    end
  end

  post '/documents/:id/favorite' do
    document = Document.find(params[:id])

    @utils_service.user.favorite_documents << document
    status 200 # Éxito
  end

  delete '/documents/:id/unfavorite' do
    document = Document.find(params[:id])

    if @utils_service.user.favorite_documents.include?(document)
      @utils_service.user.favorite_documents.delete(document) # Elimina el documento de los favoritos
      status 200 # Respuesta 200 OK si se elimina correctamente
    else
      erb :status404
    end

    redirect '/favorites'
  end
end
