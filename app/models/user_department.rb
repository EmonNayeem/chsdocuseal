# frozen_string_literal: true

# == Schema Information
#
# Table name: user_departments
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_departments_on_department_id_and_user_id  (department_id,user_id)
#  index_user_departments_on_user_id_and_department_id  (user_id,department_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (department_id => departments.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class UserDepartment < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :user_id, uniqueness: { scope: :department_id }
  validate :same_account
  validate :same_company

  private

  def same_account
    return if user.blank? || department.blank?
    return if user.account_id == department.account_id

    errors.add(:department, 'must belong to the same account as the user')
  end

  def same_company
    return if user.blank? || department.blank?
    return if user.platform_admin?
    return if user.company_id == department.company_id

    errors.add(:department, 'must belong to the same company as the user')
  end
end
