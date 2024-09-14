class CreateQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :questions do |t|
      t.string :content
      t.references :document, foreign_key: true

      t.timestamps
    end
  end
end
