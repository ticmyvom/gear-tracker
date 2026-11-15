# A personal access token that lets an agent or script use the JSON API as its
# user. Only a SHA-256 digest is stored; the token itself is available once,
# right after it's created, to show to the user.
class ApiToken < ApplicationRecord
  PERMISSIONS = { "read" => "Read only", "write" => "Read and write" }.freeze

  belongs_to :user

  attr_reader :token

  before_validation :generate_token, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :permission, inclusion: { in: PERMISSIONS.keys }
  validates :token_digest, presence: true, uniqueness: true

  def self.authenticate(token)
    find_by(token_digest: digest(token)) if token.present?
  end

  # Tokens are long and random, so a fast hash is enough; unlike passwords,
  # they can't be guessed from a list.
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def write?
    permission == "write"
  end

  # Updates last_used_at at most once a minute, so busy agents don't cause a
  # database write on every request.
  def used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  private
    def generate_token
      @token = "gt_#{SecureRandom.base58(40)}"
      self.token_digest = self.class.digest(@token)
    end
end
