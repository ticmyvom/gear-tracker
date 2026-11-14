# A record whose amount has its own currency, picked on its form. A new record
# defaults to the owner's currency setting, and changing that setting later
# doesn't touch existing records. Including models define `currency_owner`.
module Priced
  extend ActiveSupport::Concern

  included do
    before_validation(on: :create) { self.currency = currency_owner&.currency if currency.blank? }
    validates :currency, inclusion: { in: User::CURRENCIES.keys }
  end

  # Before it's saved, a new record shows the owner's current currency.
  def display_currency
    currency.presence || currency_owner&.currency
  end
end
