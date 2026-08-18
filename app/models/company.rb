# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  brand_from_email_name     :string
#  brand_icon_key            :string
#  brand_logo_key            :string
#  brand_name                :string
#  brand_primary_color       :string
#  branding_enabled          :boolean          default(FALSE), not null
#  code                      :string           not null
#  name                      :string           not null
#  smtp_address              :string
#  smtp_authentication       :string
#  smtp_domain               :string
#  smtp_enable_starttls_auto :boolean          default(FALSE), not null
#  smtp_enabled              :boolean          default(FALSE), not null
#  smtp_from_email           :string
#  smtp_from_name            :string
#  smtp_password             :text
#  smtp_port                 :integer
#  smtp_user_name            :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
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

  encrypts :smtp_password

  with_options if: :smtp_enabled? do
    validates :smtp_address, presence: true
    validates :smtp_port, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :smtp_from_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  end

  with_options if: :branding_enabled? do
    validates :brand_name, presence: true
  end

  validates :brand_primary_color, format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/, allow_blank: true }

  def branded_name
    (branding_enabled? && brand_name.presence) || name
  end

  def branded_primary_color
    brand_primary_color.presence if branding_enabled?
  end
end
