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

ActiveRecord::Schema[8.1].define(version: 2026_08_07_133513) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reports", force: :cascade do |t|
    t.binary "content", null: false
    t.datetime "created_at", null: false
    t.string "date_range_label"
    t.date "end_date", null: false
    t.string "filename", null: false
    t.string "format", default: "html", null: false
    t.datetime "generated_at", null: false
    t.jsonb "metrics_payload", default: {}, null: false
    t.string "preset"
    t.string "repository_full_name", null: false
    t.bigint "repository_id"
    t.date "start_date", null: false
    t.bigint "team_id"
    t.string "team_name", null: false
    t.datetime "updated_at", null: false
    t.index ["format"], name: "index_reports_on_format"
    t.index ["generated_at"], name: "index_reports_on_generated_at"
    t.index ["repository_full_name"], name: "index_reports_on_repository_full_name"
    t.index ["repository_id"], name: "index_reports_on_repository_id"
    t.index ["team_id"], name: "index_reports_on_team_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "owner", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["owner", "name"], name: "index_repositories_on_owner_and_name", unique: true
    t.index ["team_id"], name: "index_repositories_on_team_id"
  end

  create_table "team_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "github_username"
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "email"], name: "index_team_members_on_team_id_and_email", unique: true
    t.index ["team_id", "github_username"], name: "index_team_members_on_team_id_and_github_username", unique: true, where: "((github_username IS NOT NULL) AND ((github_username)::text <> ''::text))"
    t.index ["team_id"], name: "index_team_members_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  add_foreign_key "reports", "repositories", on_delete: :nullify
  add_foreign_key "reports", "teams", on_delete: :nullify
  add_foreign_key "repositories", "teams"
  add_foreign_key "team_members", "teams"
end
