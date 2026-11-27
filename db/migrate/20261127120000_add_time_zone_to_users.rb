# The user's time zone, like "America/Los_Angeles", so "today" is their day,
# not the server's (UTC). Empty until the browser or Settings fills it in.
class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string
  end
end
