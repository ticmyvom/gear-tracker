# Public profiles, listed at /u and shown at /u/<username>, to anyone, signed
# in or not. A private profile looks exactly like one that doesn't exist, so it
# can't be used to find out who has an account.
class ProfilesController < ApplicationController
  allow_unauthenticated_access
  before_action { response.headers["X-Robots-Tag"] = "noindex" } # not listed in search engines

  def index
    @users = User.public_profiles.order(Arel.sql("display_name COLLATE NOCASE"), :username)
  end

  def show
    @user = User.public_profiles.find_by!(username: params[:username].to_s.downcase)
    @gears = @user.public_gears.includes(:expenses, :fuel_entries, components: %i[ expenses fuel_entries ]).order(:name)
  end
end
