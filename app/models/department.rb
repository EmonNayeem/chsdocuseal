# frozen_string_literal: true

# == Schema Information
#
# Table name: departments
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  company_id :bigint           not null
#
# Indexes
#
#  index_departments_on_account_id           (account_id)
#  index_departments_on_company_id           (company_id)
#  index_departments_on_company_id_and_name  (company_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (company_id => companies.id)
#
class Department < ApplicationRecord
  before_validation :assign_company_from_parent, on: :create
  belongs_to :account
  belongs_to :company

  has_many :user_departments, dependent: :restrict_with_error
  has_many :users, through: :user_departments

  has_many :template_departments, dependent: :restrict_with_error
  has_many :templates, through: :template_departments

  before_validation :normalize_name

  validates :name, presence: true
  validates :name, uniqueness: { scope: :company_id, case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end

  def assign_company_from_parent
    # rubocop:disable Style/SafeNavigationChainLength
    self.company_id ||= account&.companies&.find_by(code: 'MD')&.id
    # rubocop:enable Style/SafeNavigationChainLength
  end
end
