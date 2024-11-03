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

require_relative '../models/user'

enable :sessions

class UtilsService
  def initialize(app_context)
    @app_context = app_context
  end

  def clean_param(param)
    param.to_s.strip
  end

  def clean_or_default(param, default)
    param.to_s.strip.empty? ? default : param.to_s.strip
  end

  def handle_error(error_key, error_message, redirect_path)
    session[:error_registration] = error_key
    logger.error error_message
    redirect redirect_path
  end

  # Helper method for JSON error responses
  def json_error(message, status_code)
    @app_context.status(status_code)
    json error: message
  end

  def set_error_status(status_code, error_message)
    @app_context.status(status_code)
    @error = error_message
    logger.error @error
  end

  def user
    @user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    redirect '/' unless session[:is_an_user_present]
  end

  def csrf_token
    session[:csrf] ||= SecureRandom.hex(32)
  end
end
