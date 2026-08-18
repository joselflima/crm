class Profile < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  belongs_to :tenant, optional: true

  ROLES = %w[agent admin super_admin].freeze
  enum :role, ROLES.index_by(&:itself)

  validates :role, inclusion: { in: ROLES }
  validate :tenant_presence_matches_role

  def admin_or_super_admin?
    admin? || super_admin?
  end

  private

  def tenant_presence_matches_role
    if super_admin? && tenant_id.present?
      errors.add(:tenant_id, "must be blank for super_admin")
    elsif !super_admin? && tenant_id.blank?
      errors.add(:tenant_id, "can't be blank")
    end
  end
end
