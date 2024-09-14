class Question < ActiveRecord::Base
  belongs_to :document
  has_many :options
  has_one :answer
end
