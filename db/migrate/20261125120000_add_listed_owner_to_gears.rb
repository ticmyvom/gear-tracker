# Whether a listed vehicle shows its owner's name. Off by default, even when the
# profile is public; vehicles listed before this stop showing it.
class AddListedOwnerToGears < ActiveRecord::Migration[8.1]
  def change
    add_column :gears, :listed_owner, :boolean, default: false, null: false
  end
end
