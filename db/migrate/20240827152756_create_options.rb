# frozen_string_literal: true

class CreateOptions < ActiveRecord::Migration[7.1] # rubocop:disable Style/Documentation
  def change
    create_table :options do |t|
      t.string :content
      t.references :question, foreign_key: true

      t.timestamps
    end
  end
end
