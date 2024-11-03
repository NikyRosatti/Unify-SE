# frozen_string_literal: true

require 'sinatra/base'

class ApplicationController < Sinatra::Base
  def self.call(*args)
    new(*args).call
  end
end
