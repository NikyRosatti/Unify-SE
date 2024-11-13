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

require_relative '../app/models/user'

require_relative 'utils'

# Helper module to handle user methods
module UserService
  def login_successfully?(username_or_email, password)
    return unless find_user_by_credentials(username_or_email, password)

    session[:is_an_user_present] = true
    session[:user_id] = find_user_by_credentials(username_or_email, password).id
    logger.info 'Sesion iniciada'
    redirect '/'
  end

  def login_incorrect
    set_error_status(503, 'No se encontró el usuario o el correo, o la contraseña es incorrecta!')
    erb :login
  end

  def existent_user?(params)
    return unless find_user(params[:username], params[:email])

    session[:error_registration] = 'user_exists'
    logger.error 'An user with that username or email already exists. Please try a different one.'
    redirect '/error_register'
  end

  def register_user(params)
    params[:b_day].presence ? Date.parse(params[:b_day]) : nil
    params[:gender].presence

    user = build_user(params)

    if user.persisted?
      handle_successful_registration(user)
    else
      handle_error_registration
    end
  end

  def build_user(params) # rubocop:disable Metrics/MethodLength
    User.create(
      username: clean_param(params[:username]),
      name: clean_param(params[:name]),
      lastname: clean_or_default(params[:lastname], 'UnknownLastName'),
      cellphone: clean_or_default(params[:cellphone], 'UnknownCellphone'),
      b_day: params[:b_day],
      gender: clean_or_default(params[:gender], 'UnknownGender'),
      email: clean_param(params[:email]),
      password: clean_param(params[:password]),
      is_admin: 0
    )
  end

  def profile_update(params)
    user.update(
      username: clean_param(params[:username]),
      name: clean_param(params[:name]),
      lastname: clean_param(params[:lastname]),
      cellphone: params[:cellphone],
      b_day: params[:b_day],
      gender: params[:gender],
      email: clean_param(params[:email])
    )
  end

  def find_user_by_credentials(username_or_email, password_)
    user = User.find_by(username: username_or_email) ||
           User.find_by(email: username_or_email)
    user&.authenticate(password_) ? user : nil
  end

  def fields_missing?(params)
    required_fields = %i[username name email password]
    return unless required_fields.any? { |field| params[field].to_s.strip.empty? }

    session[:error_registration] = 'missing_fields'
    logger.error 'Fields Username, Name, Email and Password must be filled out. Please try again.'
    redirect '/error_register'
  end

  def find_user(username, email)
    User.find_by(username: username.to_s.strip) || User.find_by(email: email.to_s.strip)
  end

  def find_user_username(username)
    User.find_by(username: username.to_s.strip)
  end

  def find_user_email(email)
    User.find_by(email: email.to_s.strip)
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

  def handle_successful_registration(user)
    session[:is_an_user_present] = true
    session.delete(:error_registration)
    session[:user_id] = user.id
    redirect '/'
  end

  def handle_error_registration
    session[:error_registration] = 'user_not_persisted'
    logger.error 'There was a problem registering your account. Please try again later.'
    redirect '/error_register'
  end

  def self.passwords_match?(new_password, confirm_password)
    new_password == confirm_password
  end
end
