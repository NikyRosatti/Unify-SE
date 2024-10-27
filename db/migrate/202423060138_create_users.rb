# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[6.0] # rubocop:disable Style/Documentation
  def change # rubocop:disable Metrics/MethodLength
    create_table :users do |t|
      t.string :username, unique: true
      t.string :name
      t.string :lastname
      t.string :cellphone
      t.string :email, unique: true
      t.string :password
      t.date   :b_day
      t.string :gender
      t.integer :is_admin, default: 0
      t.integer :correct_answers, default: 0
      t.timestamps
    end
  end
end
