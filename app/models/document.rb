class Document < ActiveRecord::Base
  has_many :questions
  has_many :favorites
  has_many :favorited_by_users, through: :favorites, source: :user
end
