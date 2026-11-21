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

  # Profile addresses are /u/<username>; these would be confusing or misleading there.
  RESERVED_USERNAMES = %w[ admin administrator api app gear gears help me mod moderator new privacy root settings support system ].freeze

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(name) { name.strip.downcase.presence }
  normalizes :display_name, with: ->(name) { name.squish.presence }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :currency, inclusion: { in: CURRENCIES.keys }
  validates :distance_unit, inclusion: { in: Units::DISTANCES.keys }
  validates :volume_unit, inclusion: { in: Units::VOLUMES.keys }
  validates :username, uniqueness: true, allow_nil: true,
    format: { with: /\A[a-z0-9](?:[a-z0-9-]{1,28}[a-z0-9])\z/, message: "must be 3–30 lowercase letters, numbers or dashes, not starting or ending with a dash" },
    exclusion: { in: RESERVED_USERNAMES, message: "is reserved" }
  validates :display_name, length: { maximum: 50 }
  validates :username, :display_name, presence: { message: "is needed for a public profile" }, if: :profile_public?

  # Gear shown on the public profile: public top-level gear, while the profile is public.
  def public_gears
    profile_public? ? gears.top_level.where(public: true) : gears.none
  end
end
