# frozen_string_literal: true

# Class to store answers into the database
#
# == Relations
# belongs to one Question
# is one of the stored Option
class Answer < ActiveRecord::Base
  belongs_to :question
  belongs_to :option
end
