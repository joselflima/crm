class Tenant < ApplicationRecord
  belongs_to :plan, optional: true
  has_many :profiles, dependent: :destroy
  has_many :channels, dependent: :destroy
  has_one :tenant_secret, dependent: :destroy

  # Mirrors the tenant_status PostgreSQL enum.
  STATUSES = %w[trial active past_due suspended canceled].freeze

  validates :status, inclusion: { in: STATUSES }
end
