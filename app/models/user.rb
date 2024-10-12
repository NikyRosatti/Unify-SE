class User < ActiveRecord::Base
  validates :username, uniqueness: true
  validates :email, uniqueness: true
  has_many :documents
  has_many :favorites
  has_many :favorite_documents, through: :favorites, source: :document
end
