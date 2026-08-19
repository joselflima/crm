class Channel < ApplicationRecord
  # The `type` column stores the channel provider (whatsapp/instagram), not a
  # Rails STI discriminator — disable STI so ActiveRecord treats it as a
  # normal attribute.
  self.inheritance_column = nil

  belongs_to :tenant

  # Both columns are PostgreSQL enums (channel_type / channel_status); these
  # lists have to stay in sync with them.
  TYPES = %w[whatsapp instagram].freeze
  STATUSES = %w[pending connected error disabled].freeze

  enum :type, TYPES.index_by(&:itself)
  enum :status, STATUSES.index_by(&:itself)

  validates :display_name, presence: true
  validates :external_id, presence: true, uniqueness: { scope: :type }
end
