class User < ApplicationRecord
  # Currency only changes how amounts are shown; it doesn't convert them.
  CURRENCIES = {
    "USD" => { name: "US dollar", symbol: "$" },
    "EUR" => { name: "Euro", symbol: "€" },
    "GBP" => { name: "British pound", symbol: "£" },
    "CAD" => { name: "Canadian dollar", symbol: "CA$" },
    "AUD" => { name: "Australian dollar", symbol: "A$" },
    "JPY" => { name: "Japanese yen", symbol: "¥", precision: 0 },
    "KRW" => { name: "South Korean won", symbol: "₩", precision: 0 },
    "INR" => { name: "Indian rupee", symbol: "₹" },
    "MXN" => { name: "Mexican peso", symbol: "MX$" },
    "VND" => { name: "Vietnamese dong", symbol: "₫", precision: 0, format: "%n %u" }
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :gears, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :currency, inclusion: { in: CURRENCIES.keys }
  validates :distance_unit, inclusion: { in: Units::DISTANCES.keys }
  validates :volume_unit, inclusion: { in: Units::VOLUMES.keys }
end
