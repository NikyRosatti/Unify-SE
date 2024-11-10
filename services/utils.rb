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

require_relative '../app/models/user'

# Helper module for utils methods.
module UtilsService
  def clean_param(param)
    param.to_s.strip
  end

  def clean_or_default(param, default)
    param.to_s.strip.empty? ? default : param.to_s.strip
  end

  # Helper method for JSON error responses
  def json_error(message, status_code)
    status(status_code)
    json error: message
  end

  def set_error_status(status_code, error_message)
    status(status_code)
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
