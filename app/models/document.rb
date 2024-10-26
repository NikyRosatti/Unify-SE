# frozen_string_literal: true

# Class to store documents into the database
#
# == Relations
# has many Question in it
# can be favorited_by_users through one or more User by Favorite
class Document < ActiveRecord::Base
  has_many :questions
  has_many :favorites
  has_many :favorited_by_users, through: :favorites, source: :user
end
