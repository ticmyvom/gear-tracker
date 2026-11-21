# Adds the gear and records from a "Download all your data" file to an account.
# It all happens in one transaction, so a file with a problem changes nothing.
# Ids and computed fields (totals, rates, efficiency) in the file are ignored,
# and fuel amounts and distances are converted from the file's units.
class AccountImport
  MAX_SIZE = 5.megabytes

  class Invalid < StandardError; end

  GEAR_FIELDS = %w[ name category power_source price currency purchased_from notes created_at ].freeze
  # Each record type: its association, date column, and the fields copied as they are.
  RECORDS = {
    "expenses" => [ :spent_on, %w[ description category amount currency vendor notes created_at ] ],
    "fuel_entries" => [ :filled_on, %w[ total_price currency minutes notes created_at ] ],
    "readings" => [ :read_on, %w[ name value unit notes created_at ] ]
  }.freeze

  attr_reader :counts

  def initialize(user, json)
    @user = user
    @data = JSON.parse(json.to_s, decimal_class: BigDecimal)
    raise Invalid unless @data.is_a?(Hash) && @data["gears"].is_a?(Array) && @data["account"].is_a?(Hash)

    @distance_unit = @data["account"]["distance_unit"]
    @volume_unit = @data["account"]["volume_unit"]
    raise Invalid unless Units::DISTANCES.key?(@distance_unit) && Units::VOLUMES.key?(@volume_unit)
  rescue JSON::ParserError, Invalid
    raise Invalid, "That isn't a Gear Tracker data file. Use one from “Download all your data”."
  end

  # Returns how many gears and records were added.
  def save!
    @counts = Hash.new(0)
    new_ids = {}

    ActiveRecord::Base.transaction do
      # Top-level gear first, so components can be attached to their new parent.
      gears = @data["gears"].each { check_hash(it) }.sort_by { it["parent_id"] ? 1 : 0 }
      gears.each do |item|
        gear = @user.gears.new(fields(item, GEAR_FIELDS).merge(purchased_on: date(item["purchased_on"], "purchased_on")))
        if item["parent_id"]
          gear.parent_id = new_ids.fetch(item["parent_id"]) { raise Invalid, "#{describe(item)} is a component of gear that isn't in the file." }
        end
        save(gear, describe(item))
        new_ids[item["id"]] = gear.id

        RECORDS.each do |association, (date_column, copied)|
          Array(item[association]).each do |entry|
            check_hash(entry)
            record = gear.public_send(association).new(fields(entry, copied).merge(date_column => date(entry["date"], "date")))
            convert_fuel_units(record, entry) if record.is_a?(FuelEntry)
            save(record, "A #{association.singularize.humanize(capitalize: false)} of #{describe(item)}")
          end
        end
      end
    end

    @counts
  rescue ActiveRecord::ActiveRecordError
    raise Invalid, "Some of the file couldn't be saved."
  end

  private
    def fields(item, names)
      item.slice(*names).each { |name, value| check_value(value, name) }
    end

    # The file stores fuel in its account's units; the database keeps liters (or kWh) and kilometers.
    def convert_fuel_units(record, entry)
      record.unit = FuelEntry.unit_for_kind(entry["kind"])
      record.amount = number(entry["amount"], "amount").then { record.unit == "l" ? Units.convert(it, @volume_unit, "l") : it }
      record.odometer = Units.convert(number(entry["odometer"], "odometer"), @distance_unit, "km")
      record.trip = Units.convert(number(entry["trip"], "trip"), @distance_unit, "km")
    end

    def number(value, name)
      check_value(value, name)
      BigDecimal(value.to_s, exception: false) if value.present?
    end

    # Dates must be YYYY-MM-DD, as the export writes them; anything else would be quietly dropped.
    def date(value, name)
      check_value(value, name)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      raise Invalid, "The file has a #{name} that isn't a date like 2026-01-31: #{value.to_s.truncate(30)}."
    end

    def save(record, description)
      record.save || raise(Invalid, "#{description}: #{record.errors.full_messages.to_sentence}.")
      @counts[record.class.model_name.human.pluralize.downcase] += 1
    end

    def describe(item)
      "Gear “#{item["name"].to_s.truncate(50)}”"
    end

    def check_hash(item)
      raise Invalid, "The file has an unexpected entry." unless item.is_a?(Hash)
    end

    def check_value(value, name)
      return if value.nil? || value.is_a?(String) || value.is_a?(Numeric)

      raise Invalid, "The file has an unexpected value for #{name}."
    end
end
