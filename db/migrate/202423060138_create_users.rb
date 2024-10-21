class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :username, unique: true
      t.string :name
      t.string :lastname
      t.string :cellphone
      t.string :email, unique: true
      t.string :password
      t.integer :is_admin, default: 0
      t.integer :correct_answers, default: 0
      t.timestamps
    end
  end
end
