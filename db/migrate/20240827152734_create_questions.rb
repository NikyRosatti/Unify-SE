class CreateQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :questions do |t|
      t.string :content
      t.references :document, foreign_key: true
      t.integer :number_answers_answered, default: 0
      t.integer :correct_answers_cant, default: 0
      t.timestamps
    end
  end
end
