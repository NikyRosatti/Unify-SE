# frozen_string_literal: true

# Class to store users into the database
#
# == Relations
# validates that username and email are unique keys
# has many Document
# they can have many favorite_documents through Favorite using Document
class User < ActiveRecord::Base
  validates :username, uniqueness: true
  validates :email, uniqueness: true
  has_many :documents
  has_many :favorites
  has_many :favorite_documents, through: :favorites, source: :document
end
