# frozen_string_literal: true

# Correr app: rackup config.ru
# http://127.0.0.1:9292/

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
require 'rack/method_override'

require './helpers'

Dir['./app/models/*.rb'].sort.each { |file| require file }

Dir['./app/controllers/*.rb'].sort.each { |file| require_relative file }

# Class App
# Main class of the program
class App < Sinatra::Base
  use Rack::MethodOverride # Para que funcionen bien los metodos delete

  ENV['SESSION_SECRET'] || 'default_secret'
  enable :sessions

  set :allow_origin, 'http://127.0.0.1:3000'
  set :port, 3000
  set :database_file, './config/database.yml'

  use MainController
  use UsersController
  use PracticeController
  use DocumentsController
end
