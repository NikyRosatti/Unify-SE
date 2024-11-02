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

ENV['APP_ENV'] = 'test'

require_relative '../app'
require 'spec_helper'
require 'rack/test'
require 'rspec'

describe 'GET /give_me_admin_please' do
  context 'cuando el usuario está autenticado' do
    it 'muestra la vista de admin si el usuario está autenticado' do
      user = User.create(username: 'testuser')
      session_data = { user_id: user.id }

      get '/give_me_admin_please', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      expect(last_request.url).to include('/give_me_admin_please')
    end
  end

  context 'cuando el usuario no está autenticado' do
    it 'redirecciona a la página de inicio de sesión' do
      get '/give_me_admin_please'

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/')
    end
  end
end

describe 'POST /verify_admin_password' do
  context 'cuando se introduce la contraseña correcta' do
    it 'redirecciona a /give_me_admin_please y establece la sesión como verificada' do
      user = User.create(username: 'testuser')
      session_data = { user_id: user.id, admin_pw_verified: false }
      correct_password =
        'You->ShouldCopy()ThisString$$InOrderToBeARealAdmin,,,Otherwise~YouWillGetConfused!!And&WontBeAbleToBeAnAdmin!!'
      post '/verify_admin_password', { entered_pw: correct_password.to_s }, 'rack.session' => session_data

      expect(last_request.env['rack.session'][:admin_pw_verified]).to eq(user.is_admin == 1)
    end
  end

  context 'cuando se introduce una contraseña incorrecta' do
    it 'redirecciona a /give_me_admin_please con un error y establece la sesión como no verificada' do
      user = User.create(username: 'testuser')
      session_data = { user_id: user.id }
      incorrect_password = 'incorrectPassword'
      post '/verify_admin_password', { entered_pw: incorrect_password }, 'rack.session' => session_data

      # expect(last_response).to be_redirect
      # follow_redirect!
      # expect(last_request.url).to include('/give_me_admin_please?error=invalid_password')
      expect(last_request.env['rack.session'][:admin_pw_verified]).to be_falsey
    end
  end

  context 'cuando no hay un usuario autenticado' do
    it 'redirige al usuario a la página de inicio de sesión' do
      correct_password =
        'You->ShouldCopy()ThisString$$InOrderToBeARealAdmin,,,Otherwise~YouWillGetConfused!!And&WontBeAbleToBeAnAdmin!!'
      post '/verify_admin_password', { entered_pw: correct_password }

      expect(last_response).to be_redirect
      expect(last_response.location).to include('/')
    end
  end
end

describe 'POST /give_me_admin_please' do
  context 'cuando el usuario y la sesión de admin están verificadas' do
    it 'actualiza al usuario a admin y redirecciona a /give_me_admin_please' do
      user = User.create(username: 'testuser', is_admin: false)
      session_data = { user_id: user.id, admin_pw_verified: true }

      post '/give_me_admin_please', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/give_me_admin_please')
      expect(User.find(user.id).is_admin).to eq(1)
      expect(last_request.env['rack.session'][:admin_pw_verified]).to be_falsey
    end
  end

  context 'cuando no se encuentra el usuario o la sesión no está verificada' do
    it 'redirecciona a /give_me_admin_please con un error de acceso no autorizado' do
      session_data = { user_id: nil, admin_pw_verified: false }

      post '/give_me_admin_please', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/give_me_admin_please?error=unauthorized_access')
    end
  end
end

describe 'POST /remove_me_from_admins_please' do
  context 'cuando el usuario es encontrado' do
    it 'remueve el estado de admin del usuario y redirecciona a /give_me_admin_please' do
      user = User.create(username: 'testuser', is_admin: true)
      session_data = { user_id: user.id }

      post '/remove_me_from_admins_please', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/give_me_admin_please')
      expect(User.find(user.id).is_admin).to eq(0)
    end
  end

  context 'cuando no se encuentra el usuario' do
    it 'logea un error y redirecciona a /give_me_admin_please' do
      session_data = { user_id: nil }

      post '/remove_me_from_admins_please', {}, 'rack.session' => session_data

      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_request.url).to include('/give_me_admin_please')
    end
  end
end
