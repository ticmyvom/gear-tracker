# Lets people share a profile and chosen gear. Everything starts private.
class AddPublicProfiles < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :username
      t.string :display_name
      t.boolean :profile_public, null: false, default: false
      t.index :username, unique: true
    end

    change_table :gears, bulk: true do |t|
      t.boolean :public, null: false, default: false
      t.boolean :public_costs, null: false, default: false
    end
  end
end
