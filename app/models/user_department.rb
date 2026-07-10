# frozen_string_literal: true

class UserDepartment < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :user_id, uniqueness: { scope: :department_id }
  validate :same_account

  private

  def same_account
    return if user.blank? || department.blank?
    return if user.account_id == department.account_id

    errors.add(:department, 'must belong to the same account as the user')
  end
end
