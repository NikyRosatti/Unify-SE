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

require './config/environment'

set :allow_origin, 'http://127.0.0.1:3000'
set :port, 3000
enable :sessions

# Variable global a los metodos utilizada en POST Register para manejar errores
error_registration = ''

before do
  @isAnUserPresent = session[:isAnUserPresent] || false
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

get '/error-register' do
  case error_registration
  when 'missing_fields'
    erb :error_missing_fields
  when 'user_exists'
    erb :error_user_exists
  when 'user_not_persisted'
    erb :error_registration_failed
  else
    redirect '/register'
  end
end

get '/logout' do
  session[:isAnUserPresent] = false
  redirect '/'
end

post '/login' do
  if !session[:isAnUserPresent]
    username_or_email = params[:username_or_email]
    password = params[:password]

    if username_or_email && password
      @user = User.find_by(username: username_or_email, password: password) || User.find_by(email: username_or_email, password: password)
      if @user
        session[:isAnUserPresent] = true
        redirect '/'
      else
        @error = 'No se encontró el usuario o el correo, o la contraseña es incorrecta!'
        erb :login
      end
    else
      @error = 'Ingrese el nombre de usuario o correo electronico y la contraseña!'
      erb :login
    end
  else
    @error = 'Para entrar en una cuenta primero se debe salir de la cuenta actual!'
    erb :login
  end
end

post '/register' do
  username = params[:username]
  name = params[:name]
  lastname = params[:lastname] || 'Apellido No registrado'
  cellphone = params[:cellphone] || 'Celular No registrado'
  email = params[:email]
  password = params[:password]

  if username.nil? || name.nil? || email.nil? || password.nil? || username.strip.empty? || name.strip.empty? || email.strip.empty? || password.strip.empty?
    error_registration = 'missing_fields'
    redirect '/error-register'
    # Entra solamente por aca cuando se ponen espacios, porque el ".nil?" ya lo controla el form en el ERB con la clausula "required"
  else
    @user = User.find_by(username: username) || User.find_by(email: email)
    if @user
      error_registration = 'user_exists'
      redirect '/error-register'
    else
      @user = User.create(username: username, name: name, lastname: lastname, cellphone: cellphone, email: email,
                          password: password)
      if @user.persisted?
        error_registration = ''
        session[:isAnUserPresent] = true
        redirect '/'
      else
        error_registration = 'user_not_persisted'
        redirect '/error-register'
      end
    end
  end
end

post '/logout' do
  session[:isAnUserPresent] = false
  redirect '/'
end
