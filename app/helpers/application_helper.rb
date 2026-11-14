module ApplicationHelper
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

  def quantity(value)
    number_with_precision value, precision: 3, strip_insignificant_zeros: true
  end
end
