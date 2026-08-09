# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_companies_on_account_id           (account_id)
#  index_companies_on_account_id_and_code  (account_id,code) UNIQUE
#  index_companies_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Company < ApplicationRecord
  belongs_to :account

  has_many :users, dependent: :restrict_with_error
  has_many :departments, dependent: :restrict_with_error
  has_many :templates, dependent: :restrict_with_error
  has_many :submissions, dependent: :restrict_with_error
  has_many :submitters, dependent: :restrict_with_error
  has_many :template_folders, dependent: :restrict_with_error
  has_many :template_versions, dependent: :restrict_with_error
  has_many :submission_events, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :code, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
end
