class Plan < ApplicationRecord
  has_many :tenants, dependent: :restrict_with_error
end
