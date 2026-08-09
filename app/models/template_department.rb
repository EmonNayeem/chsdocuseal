# frozen_string_literal: true

# == Schema Information
#
# Table name: template_departments
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint           not null
#  template_id   :bigint           not null
#
# Indexes
#
#  index_template_departments_on_department_id_and_template_id  (department_id,template_id)
#  index_template_departments_on_template_id_and_department_id  (template_id,department_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (department_id => departments.id) ON DELETE => cascade
#  fk_rails_...  (template_id => templates.id) ON DELETE => cascade
#
class TemplateDepartment < ApplicationRecord
  belongs_to :template
  belongs_to :department

  validates :template_id, uniqueness: { scope: :department_id }
  validate :same_account
  validate :same_company

  private

  def same_account
    return if template.blank? || department.blank?
    return if template.account_id == department.account_id

    errors.add(:department, 'must belong to the same account as the template')
  end

  def same_company
    return if template.blank? || department.blank?
    return if template.company_id == department.company_id

    errors.add(:department, 'must belong to the same company as the template')
  end
end
