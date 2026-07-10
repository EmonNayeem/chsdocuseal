# frozen_string_literal: true

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
