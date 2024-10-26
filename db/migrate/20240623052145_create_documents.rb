# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[7.1] # rubocop:disable Style/Documentation
  def change
    create_table :documents do |t|
      t.string :filename
      t.binary :filecontent
      t.string :file_hash
      t.date :uploaddate

      t.timestamps
    end
    # Hace que file_hash tenga un indice unico para cada archivo
    add_index :documents, :file_hash, unique: true
  end
end
