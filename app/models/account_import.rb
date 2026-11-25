# Adds the gear and records from a "Download all your data" file to an account
# that has no gear yet, so importing a file twice can't make copies. It all
# happens in one transaction, so a file with a problem changes nothing.
# Imported gear starts private, whatever the file says, and the profile isn't
# imported. Ids and computed fields (totals, rates, efficiency) are ignored,
# and fuel amounts and distances are converted from the file's units.
class AccountImport
  MAX_SIZE = 5.megabytes

  class Invalid < StandardError; end

  GEAR_FIELDS = [ "name", *Gear::VEHICLE_FIELDS.map(&:to_s), "power_source", "price", "currency", "purchased_from", "notes", "created_at" ].freeze
  # Each record type: its association, date column, and the fields copied as they are.
  RECORDS = {
    "expenses" => [ :spent_on, %w[ description amount currency vendor notes created_at ] ],
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
      raise Invalid, "Your account already has gear. Import only works into an account with none, so nothing gets copied twice." if @user.gears.exists?

      # Top-level gear first, so components can be attached to their new parent.
      gears = @data["gears"].each { check_hash(it) }.sort_by { it["parent_id"] ? 1 : 0 }
      gears.each do |item|
        gear = @user.gears.new(fields(item, GEAR_FIELDS).merge(purchased_on: date(item["purchased_on"], "purchased_on"), **category(item, Gear)))
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
            record.odometer = distance(entry) if record.is_a?(Reading)
            record.assign_attributes(category(entry, Expense)) if record.is_a?(Expense)
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
      record.odometer = distance(entry)
      record.trip = distance(entry, "trip")
      record.filled_up = boolean(entry, "filled_up", default: true)
      record.missed_previous = boolean(entry, "missed_previous", default: false)
      record.efficiency_checked = boolean(entry, "efficiency_checked", default: false)
    end

    def distance(entry, field = "odometer")
      Units.convert(number(entry[field], field), @distance_unit, "km")
    end

    # Older files leave these out, and get the default, like entries made back then.
    def boolean(entry, name, default:)
      entry.fetch(name, default).tap do |value|
        raise Invalid, "The file has an unexpected value for #{name}." unless [ true, false ].include?(value)
      end
    end

    # Older files have free-text categories: a known name is kept, and anything
    # else becomes "other", with the old text at the top of the notes.
    def category(item, model)
      text = item["category"].tap { check_value(it, "category") }.to_s.strip
      return { category: nil } if text.empty?

      if (key = model.category_key_for(text))
        { category: key }
      else
        { category: "other", notes: [ "Category: #{text}", item["notes"].presence ].compact.join("\n\n") }
      end
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
