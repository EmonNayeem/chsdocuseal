# frozen_string_literal: true

class TemplateDepartment < ApplicationRecord
  belongs_to :template
  belongs_to :department

  validates :template_id, uniqueness: { scope: :department_id }
  validate :same_account

  private

  def same_account
    return if template.blank? || department.blank?
    return if template.account_id == department.account_id

    errors.add(:department, 'must belong to the same account as the template')
  end
end
