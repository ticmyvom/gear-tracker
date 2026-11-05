module ApplicationHelper
  def money(amount)
    amount.nil? ? "-" : number_to_currency(amount)
  end

  def quantity(value)
    number_with_precision value, precision: 3, strip_insignificant_zeros: true
  end
end
