class Tenant < ApplicationRecord
  belongs_to :plan, optional: true
  has_many :profiles, dependent: :destroy
  has_many :channels, dependent: :destroy
  has_one :tenant_secret, dependent: :destroy

  validates :status, inclusion: { in: %w[trial active past_due] }
end
