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

require_relative '../app/models/user'

require_relative 'utils'

# Helper module to handle user methods
module UserService
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
end
