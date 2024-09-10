class Question < ActiveRecord::Base
  has_many :options
  has_one :answer
end