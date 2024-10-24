# frozen_string_literal: true

# Class to store options into the database
#
# == Relations
# belongs to one Question
class Option < ActiveRecord::Base
  belongs_to :question
end
