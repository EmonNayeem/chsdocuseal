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
#
# Indexes
#
#  index_departments_on_account_id           (account_id)
#  index_departments_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Department < ApplicationRecord
  belongs_to :account

  has_many :user_departments, dependent: :restrict_with_error
  has_many :users, through: :user_departments

  has_many :template_departments, dependent: :restrict_with_error
  has_many :templates, through: :template_departments

  before_validation :normalize_name

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
