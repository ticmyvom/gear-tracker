class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      fill_in_time_zone user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    # Accounts made before time zones existed get the browser's on their next sign-in.
    # A zone already saved is kept, so signing in while traveling doesn't change it.
    def fill_in_time_zone(user)
      user.update(time_zone: params[:time_zone]) if user.time_zone.nil? && params[:time_zone].present?
    end
end
