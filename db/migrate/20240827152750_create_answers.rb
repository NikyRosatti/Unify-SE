# frozen_string_literal: true

class CreateAnswers < ActiveRecord::Migration[7.1] # rubocop:disable Style/Documentation
  def change
    create_table :answers do |t|
      t.references :question, foreign_key: true
      t.references :option, foreign_key: true

      t.timestamps
    end
  end
end
