class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :filename
      t.binary :filecontent
      t.date :uploaddate

      t.timestamps
    end
  end
end
