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

require_relative '../models/question'
require_relative '../models/user'

require_relative '../../helpers'

# Main controller
# It handles the general purpose views from the app
class MainController < Sinatra::Base
  helpers DocumentService
  helpers PracticeService
  helpers UserService
  helpers UtilsService
  enable :sessions

  before do
    session[:is_an_user_present] = session[:is_an_user_present] || false
    @is_an_user_present = session[:is_an_user_present] || false
  end

  get '/' do
    erb :index
  end

  get '/question_statistics' do
    authenticate_user!
    if user.is_admin?
      # Tipo de filtro a aplicar
      filter = params[:filter]

      @top_correct_questions = Question.order(correct_answers_cant: :desc).limit(10)
      @top_incorrect_questions = Question.select('questions.* ,
      (number_answers_answered - correct_answers_cant) AS incorrect_answers')
                                         .order('incorrect_answers DESC')
                                         .limit(10)

      if filter == 'correct'
        @top_questions = @top_correct_questions
        @title = 'Top 10 Questions Answered Correctly'
      else
        @top_questions = @top_incorrect_questions
        @title = 'Top 10 Questions Answered Incorrectly'
      end
      erb :question_statistics
    else
      halt 404, 'Access denied due to user level.'
      # redirect "/"
    end
  end

  get '/no_key_provided' do
    erb :no_key_provided
  end

  # Para ayudarnos y obtener la tabla general de progreso
  get '/progress' do
    @users = User.all.order(correct_answers: :desc)
    erb :leaderboard
  end

  get '/settings' do
    authenticate_user!
    if user
      rank
      erb :account_settings
    else
      erb :status404
    end
  end

  get '/privacy' do
    # erb :privacy
    erb :status404
  end

  delete '/settings/:id' do
    if user&.destroy
      session.clear
      redirect '/logout'
    else
      redirect '/settings'
    end
  end
end
