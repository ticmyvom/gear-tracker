module ApplicationHelper
  # The gear page, scrolled to the section listing this kind of record.
  def gear_section_path(gear, model)
    gear_path(gear, anchor: model.model_name.route_key)
  end

  # A gear page section's heading, scrolled to after saving one of its records,
  # so adding several in a row doesn't mean scrolling down each time.
  def section_heading(model, text)
    id = model.model_name.route_key
    tag.h2 text, id: id, data: ({ controller: "scroll-into-view" } if flash[:section].to_s == id)
  end

  # Tables show a Notes column only when some row has a note.
  def any_notes?(records)
    records.any? { it.notes.present? }
  end

  def currency_options
    User::CURRENCIES.map { |code, currency| [ "#{code} #{currency[:symbol]}", code ] }
  end

  # An amount in its currency, or Costs as one amount per currency joined with "+".
  def money(amount, currency = Current.user&.currency)
    case amount
    when nil
      "-"
    when Costs
      amount.empty? ? money(0, currency) : amount.map { |code, total| money(total, code) }.join(" + ")
    else
      format = User::CURRENCIES.fetch(currency) { User::CURRENCIES["USD"] }
      number_to_currency(amount, unit: format[:symbol], precision: format.fetch(:precision, 2), format: format.fetch(:format, "%u%n"))
    end
  end

  # Three significant digits, so small rates like 0.00467 don't round to 0.00.
  def rate(value)
    number_with_precision value, precision: 3, significant: true, strip_insignificant_zeros: true, delimiter: ","
  end

  # 90 => "1 h 30 min", 180 => "3 h", 45 => "45 min"
  def duration(minutes)
    return if minutes.nil?

    hours, mins = minutes.divmod(60)
    [ ("#{hours} h" if hours.positive?), ("#{mins} min" if mins.positive?) ].compact.join(" ")
  end

  # 45 => "45 days", 400 => "1 year 1 month"
  def time_tracked(days)
    months = (days / 30.4375).floor
    return pluralize(days, "day") if months < 2

    years, months = months.divmod(12)
    [ (pluralize(years, "year") if years.positive?), (pluralize(months, "month") if months.positive?) ].compact.join(" ")
  end

  # A VehicleStats efficiency with its unit, like "45.1 mi/gal"
  def efficiency(stats, value)
    value ? "#{number_with_precision(value, precision: 1)} #{stats.efficiency_label}" : "-"
  end

  def quantity(value)
    number_with_precision value, precision: 3, strip_insignificant_zeros: true
  end

  # Odometers and trips, with commas for easy reading, like 120,000.5.
  def distance(value)
    number_with_precision value, precision: 1, strip_insignificant_zeros: true, delimiter: ","
  end
end
