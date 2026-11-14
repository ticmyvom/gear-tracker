module ApplicationHelper
  def money(amount)
    return "-" if amount.nil?

    currency = User::CURRENCIES.fetch(Current.user&.currency, User::CURRENCIES["USD"])
    number_to_currency(amount, unit: currency[:symbol], precision: currency.fetch(:precision, 2), format: currency.fetch(:format, "%u%n"))
  end

  def quantity(value)
    number_with_precision value, precision: 3, strip_insignificant_zeros: true
  end
end
