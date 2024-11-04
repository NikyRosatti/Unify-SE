# frozen_string_literal: true

Dir[File.join(__dir__, 'services/*.rb')].sort.each { |file| require_relative file }

helpers do
  include DocumentService
  include PracticeService
  include UserService
  include UtilsService
end
