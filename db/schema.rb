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

ActiveRecord::Schema[8.1].define(version: 2026_11_23_150000) do
  create_table "api_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "permission", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "gear_id", null: false
    t.date "spent_on", null: false
    t.string "description", null: false
    t.string "category"
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "vendor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", null: false
    t.text "notes"
    t.index ["gear_id"], name: "index_expenses_on_gear_id"
  end

  create_table "fuel_entries", force: :cascade do |t|
    t.integer "gear_id", null: false
    t.date "filled_on", null: false
    t.decimal "total_price", precision: 12, scale: 2
    t.decimal "amount", precision: 16, scale: 6, null: false
    t.decimal "odometer", precision: 16, scale: 6
    t.decimal "trip", precision: 16, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit", null: false
    t.integer "minutes"
    t.string "currency", null: false
    t.text "notes"
    t.boolean "filled_up", default: true, null: false
    t.boolean "missed_previous", default: false, null: false
    t.index ["gear_id"], name: "index_fuel_entries_on_gear_id"
  end

  create_table "gears", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "parent_id"
    t.string "name", null: false
    t.string "category"
    t.date "purchased_on"
    t.decimal "price", precision: 12, scale: 2
    t.string "purchased_from"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "power_source"
    t.string "currency", null: false
    t.boolean "public", default: false, null: false
    t.boolean "public_costs", default: false, null: false
    t.integer "year"
    t.string "make"
    t.string "model"
    t.string "trim"
    t.index ["parent_id"], name: "index_gears_on_parent_id"
    t.index ["user_id"], name: "index_gears_on_user_id"
  end

  create_table "readings", force: :cascade do |t|
    t.integer "gear_id", null: false
    t.date "read_on", null: false
    t.string "name", null: false
    t.decimal "value", precision: 12, scale: 3, null: false
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.decimal "odometer", precision: 16, scale: 6
    t.index ["gear_id"], name: "index_readings_on_gear_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "distance_unit", default: "mi", null: false
    t.string "volume_unit", default: "us_gal", null: false
    t.string "username"
    t.string "display_name"
    t.boolean "profile_public", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "api_tokens", "users"
  add_foreign_key "expenses", "gears"
  add_foreign_key "fuel_entries", "gears"
  add_foreign_key "gears", "gears", column: "parent_id"
  add_foreign_key "gears", "users"
  add_foreign_key "readings", "gears"
  add_foreign_key "sessions", "users"
end
