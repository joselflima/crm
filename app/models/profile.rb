class Profile < ApplicationRecord
  # Only :recoverable/:rememberable/:trackable would need columns
  # (reset_password_token, remember_created_at, sign_in_count, ...) that
  # don't exist on the real profiles table, so they're intentionally
  # omitted rather than added to a shared production schema.
  devise :database_authenticatable, :validatable

  belongs_to :tenant, optional: true

  # Devise's database_authenticatable expects an `encrypted_password`
  # column; the real table calls it `password_hash`. Alias rather than
  # rename the column.
  def encrypted_password
    password_hash
  end

  def encrypted_password=(value)
    self.password_hash = value
  end

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
