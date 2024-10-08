# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2024_08_27_152756) do
  create_table "answers", force: :cascade do |t|
    t.integer "question_id"
    t.integer "option_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["option_id"], name: "index_answers_on_option_id"
    t.index ["question_id"], name: "index_answers_on_question_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "filename"
    t.binary "filecontent"
    t.string "file_hash"
    t.date "uploaddate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_hash"], name: "index_documents_on_file_hash", unique: true
  end

  create_table "options", force: :cascade do |t|
    t.string "content"
    t.integer "question_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_options_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.string "content"
    t.integer "document_id"
    t.integer "number_answers_answered", default: 0
    t.integer "correct_answers_cant", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_questions_on_document_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "name"
    t.string "lastname"
    t.string "cellphone"
    t.string "email"
    t.string "password"
    t.boolean "isAdmin"
    t.integer "correct_answers", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "answers", "options"
  add_foreign_key "answers", "questions"
  add_foreign_key "options", "questions"
  add_foreign_key "questions", "documents"
end
