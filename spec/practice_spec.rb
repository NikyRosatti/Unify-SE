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

describe "POST /practice" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  context "cuando se sube un PDF válido" do
    it "recibe como ultimo status 251 por haber creado el cuestionario" do
      # Crea un usuario de prueba y simula el inicio de sesión
      User.create(username: "testuser", password: "password")
      post "/login", { username_or_email: "testuser", password: "password" }

      # Simula la subida de un archivo PDF
      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), "fixtures/sample.pdf"), "application/pdf")
      post "/practice", { file: pdf_file }, "rack.session" => { isAnUserPresent: true }

      expect(last_response.status).to eq(251)
    end
  end

  context "cuando no se proporciona un archivo" do
    it "recibe como ultimo status 510 y que la ultima respuesta sea un mensaje de error" do
      post "/practice", { file: nil }, "rack.session" => { isAnUserPresent: true }

      expect(last_response.status).to eq(510)
      expect(last_response.body).to include("No file provided")
    end
  end

  context "cuando se sube un PDF que no se puede procesar" do
    it "recibe como ultimo status 500 y que la ultima respuesta sea un mensaje de error" do
      # Crea un usuario de prueba y simula el inicio de sesión
      User.create(username: "testuser", password: "password")
      post "/login", { username_or_email: "testuser", password: "password" }

      # Simula la subida de un archivo PDF no válido
      pdf_file = Rack::Test::UploadedFile.new(File.join(File.dirname(__FILE__), "fixtures/invalid_sample.pdf"), "application/pdf")
      post "/practice", { file: pdf_file }, "rack.session" => { isAnUserPresent: true }

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include("Failed to extract text from PDF")
    end
  end
end
