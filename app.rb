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

set :allow_origin, 'http://127.0.0.1:3000'
set :port, 3000
set :database_file, './config/database.yml'

require_relative 'app/controllers/main_controller'
require_relative 'app/controllers/users_controller'
require_relative 'app/controllers/documents_controller'
require_relative 'app/controllers/practice_controller'

enable :sessions

# Class App
# Main class of the program
#
class App < Sinatra::Base
  use MainController
  use UsersController
  use PracticeController
  use DocumentsController

  before do
    @is_an_user_present = session[:is_an_user_present] || false
  end
end
