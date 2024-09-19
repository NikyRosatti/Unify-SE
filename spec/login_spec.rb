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

describe "Login App" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe "POST /login" do
    context "cuando se loguea con credenciales validas" do
      it "recibe que el usuario existe en la base de datos" do
        User.create(username: "testuser", name: "testname", lastname: "testlastname", cellphone: "testcellphone", email: "testemail",
                    password: "password")
        post "/login", { username_or_email: "testuser", password: "password" }
        expect(User.find_by(username: "testuser")).not_to be_nil
      end
    end

    context "cuando se loguea con credenciales invalidas" do
      it "recibe un mensaje de error de credenciales" do
        User.create(username: "testuser", password: "password")
        post "/login", { username_or_email: "testuser", password: "wrongpassword" }

        expect(last_response.status).to eq(503)
        expect(last_response.body).to include("No se encontró el usuario o el correo, o la contraseña es incorrecta!")
      end
    end

    context "cuando se loguea sin dar ninguna credencial" do
      it "recibe un codigo 501 como status http" do
        User.create(username: "testuser", password: "password")
        post "/login", { username_or_email: "", password: "" }

        expect(last_response.status).to eq(501)
        expect(last_response.body).to include("Ingrese el nombre de usuario o correo electronico y la contraseña!")
      end
    end

    context "cuando se quiere loguear cuando ya esta logueado" do
      it "recibe un codigo 502 como status http" do
        # Configura la sesión inicial
        post "/login", { username_or_email: "anyuser", password: "anypassword" }, "rack.session" => { isAnUserPresent: true }

        expect(last_response.status).to eq(502)
      end
    end
  end
end
