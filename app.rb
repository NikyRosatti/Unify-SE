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
