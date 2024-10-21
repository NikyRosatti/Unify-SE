# frozen_string_literal: true

# Class to handle favorite documents from users
#
# == Relations
# belongs to one User
# belongs to one Document
class Favorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :document
end
