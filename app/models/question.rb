# frozen_string_literal: true

# Class to store questions into the database
#
# == Relations
# belongs to one Document
# has many Option
# contains only one Answer
class Question < ActiveRecord::Base
  belongs_to :document
  has_many :options
  has_one :answer
end
