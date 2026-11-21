# Lets people take their data with them, bring it back, or delete it. Both need a signed-in
# browser session; API tokens can't do either.
class AccountsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: %i[ destroy import ], with: -> { redirect_to edit_settings_path, alert: "Try again later." }

  # Deletes the user and everything they own: gear, records, sessions and API tokens.
  def destroy
    if Current.user.authenticate(params[:password].to_s)
      Current.user.destroy!
      cookies.delete(:session_id)
      redirect_to new_session_path, notice: "Your account and all its data were deleted.", status: :see_other
    else
      redirect_to edit_settings_path, alert: "That password isn't right. Your account wasn't deleted.", status: :see_other
    end
  end

  # Everything the user has entered, as JSON, in the same format as the API.
  def export
    @gears = Current.user.gears.includes(:expenses, :fuel_entries, :readings, :components).order(:parent_id, :name)
    response.headers["Cache-Control"] = "no-store"
    send_data render_to_string(template: "accounts/export", formats: [ :json ]),
      filename: "gear-tracker-#{Date.current.iso8601}.json", type: :json, disposition: :attachment
  end

  # Adds the gear and records from an export file to this account.
  def import
    file = params[:file]
    raise AccountImport::Invalid, "Choose a file from “Download all your data”." unless file.respond_to?(:read)
    raise AccountImport::Invalid, "That file is too big (the limit is #{AccountImport::MAX_SIZE / 1.megabyte} MB)." if file.size > AccountImport::MAX_SIZE

    counts = AccountImport.new(Current.user, file.read).save!
    redirect_to root_path, notice: "Imported #{counts.map { |name, count| "#{count} #{count == 1 ? name.singularize : name}" }.to_sentence.presence || "nothing: the file has no gear"}.", status: :see_other
  rescue AccountImport::Invalid => error
    redirect_to edit_settings_path, alert: "#{error.message} Nothing was imported.", status: :see_other
  end
end
