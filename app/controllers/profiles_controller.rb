# Public profiles at /u/<username>, visible to anyone, signed in or not. A
# private profile looks exactly like one that doesn't exist, so it can't be
# used to find out who has an account.
class ProfilesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.find_by!(username: params[:username].to_s.downcase, profile_public: true)
    @gears = @user.public_gears.includes(:expenses, :fuel_entries, components: %i[ expenses fuel_entries ]).order(:name)
    response.headers["X-Robots-Tag"] = "noindex" # not listed in search engines
  end
end
