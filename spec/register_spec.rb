require "sinatra"
require "sinatra/activerecord"
require "sinatra/cors"
require "sinatra/json"
require "byebug"
require "fileutils"
require "dotenv/load"
require "pdf-reader"
require "json"
require "openai"
require "digest"

ENV["APP_ENV"] = "test"

require_relative "../app"
require "spec_helper"
require "rack/test"
require "rspec"

describe "POST /register" do
  context "cuando se registra un usuario con datos válidos" do
    it "crea un nuevo usuario y redirige a la página principal" do
      post "/register", {
        username: "newuser",
        name: "newname",
        lastname: "newlastname",
        cellphone: "1234567890",
        email: "newuser@example.com",
        password: "password",
      }

      expect(User.find_by(username: "newuser")).not_to be_nil
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.path).to eq("/")
    end
  end

  context "cuando faltan campos en el formulario" do
    it "redirige a /error-register con el mensaje de campos faltantes" do
      post "/register", {
        username: "",
        name: "newname",
        lastname: "newlastname",
        cellphone: "1234567890",
        email: "newuser@example.com",
        password: "password",
      }

      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.path).to eq("/error-register")
      expect(last_response.body).to include("Fields Username, Name, Email and Password must be filled out. Please try again.")
    end
  end

  context "cuando el usuario ya existe" do
    it "redirige a /error-register con el mensaje de usuario existente" do
      User.create(username: "existinguser", email: "existinguser@example.com", password: "password")

      post "/register", {
        username: "existinguser",
        name: "newname",
        lastname: "newlastname",
        cellphone: "1234567890",
        email: "existinguser@example.com",
        password: "password",
      }

      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_request.path).to eq("/error-register")
      expect(last_response.body).to include("An user with that username or email already exists. Please try a different one.")
    end
  end

  # Dificil de replicar este test porque involucra fallar en la persistencia de la base de datos
  #
  # context "cuando el usuario no se guarda correctamente" do
  #   it "redirige a /error-register con el mensaje de error al guardar" do
  #     allow_any_instance_of(User).to receive(:persisted?).and_return(false) # Simulamos fallo en persistencia

  #     post "/register", {
  #       username: "newuser",
  #       name: "newname",
  #       lastname: "newlastname",
  #       cellphone: "1234567890",
  #       email: "newuser@example.com",
  #       password: "password",
  #     }

  #     expect(last_response).to be_redirect
  #     follow_redirect!
  #     expect(last_request.path).to eq("/error-register")
  #     expect(last_response.body).to include("There was a problem registering your account. Please try again later.")
  #   end
  # end
end
