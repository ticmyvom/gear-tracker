# Vehicles their owners listed, for people choosing a car, signed in or not. They
# show only what the owner chose, never the nickname, and the owner's name only
# if they chose to and their profile is public. A vehicle that isn't listed looks exactly like
# one that doesn't exist.
class VehiclesController < ApplicationController
  include NotIndexed
  allow_unauthenticated_access

  PER_PAGE = 25

  def index
    listed = Gear.listed
    @make, @model = params[:make].to_s, params[:model].to_s
    @makes = choices(listed, :make)
    listed = listed.where("make = ? COLLATE NOCASE", @make) if @make.present?
    @models = choices(listed, :model)
    listed = listed.where("model = ? COLLATE NOCASE", @model) if @model.present?

    @page = params[:page].to_s.to_i.clamp(1, 10_000)
    vehicles = listed.includes(:user, *VehicleStats::RECORDS, components: VehicleStats::RECORDS)
      .order(Arel.sql("make COLLATE NOCASE, model COLLATE NOCASE, year DESC, id"))
      .offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = vehicles.size > PER_PAGE
    @stats = vehicles.first(PER_PAGE).map { stats_for(it) }
  end

  def show
    @vehicle = Gear.listed.find(params[:id])
    @stats = stats_for(@vehicle)
  end

  private
    # In the visitor's units, so all vehicles compare fairly; new accounts' units if they're not signed in.
    def stats_for(vehicle)
      @viewer ||= (Current.user if authenticated?) || User.new
      VehicleStats.new(vehicle, distance_unit: @viewer.distance_unit, volume_unit: @viewer.volume_unit)
    end

    def choices(vehicles, field)
      vehicles.distinct.pluck(field).compact.uniq(&:downcase).sort_by(&:downcase)
    end
end
