# Creates and revokes API tokens from the Settings page. Needs a signed-in
# browser session, so an API token can never be used to make more tokens.
class ApiTokensController < ApplicationController
  def create
    @api_token = Current.user.api_tokens.new(params.expect(api_token: %i[ name permission ]))

    if @api_token.save
      # The page shows the token itself, so browsers mustn't keep a copy.
      response.headers["Cache-Control"] = "no-store"
      render :created
    else
      @user = Current.user
      render "settings/edit", status: :unprocessable_content
    end
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy!
    redirect_to edit_settings_path, notice: "Token revoked. Agents using it can no longer sign in.", status: :see_other
  end
end
