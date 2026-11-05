module ApplicationHelper
  def money(amount)
    amount.nil? ? "-" : number_to_currency(amount)
  end
end
