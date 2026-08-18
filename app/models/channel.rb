class Channel < ApplicationRecord
  # The `type` column stores the channel provider (whatsapp/instagram), not a
  # Rails STI discriminator — disable STI so ActiveRecord treats it as a
  # normal attribute.
  self.inheritance_column = nil

  belongs_to :tenant

  TYPES = %w[whatsapp instagram].freeze
  STATUSES = %w[active inactive].freeze

  enum :type, TYPES.index_by(&:itself)
  enum :status, STATUSES.index_by(&:itself)

  validates :external_id, presence: true, uniqueness: { scope: :type }
end
