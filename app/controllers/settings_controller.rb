class SettingsController < ApplicationController
  def edit
    @user = Current.user
    @api_token = Current.user.api_tokens.new
  end

  def update
    @user = Current.user

    if @user.update(settings_params)
      redirect_to edit_settings_path, notice: "Settings saved."
    else
      @api_token = Current.user.api_tokens.new
      render :edit, status: :unprocessable_content
    end
  end

  private
    def settings_params
      params.expect(user: %i[ currency distance_unit volume_unit time_zone username display_name profile_public ])
    end
end
