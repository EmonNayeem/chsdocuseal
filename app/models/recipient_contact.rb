# frozen_string_literal: true

# == Schema Information
#
# Table name: recipient_contacts
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  name       :string
#  phone      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  company_id :bigint
#
# Indexes
#
#  index_recipient_contacts_on_account_id            (account_id)
#  index_recipient_contacts_on_account_id_and_email  (account_id,email) UNIQUE
#  index_recipient_contacts_on_company_id            (company_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (company_id => companies.id)
#
class RecipientContact < ApplicationRecord
  belongs_to :account
  belongs_to :company, optional: true

  before_validation :normalize_fields

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :account_id, case_sensitive: false }
  validate :company_belongs_to_account

  scope :visible_to, lambda { |user|
    if user.platform_admin?
      where(account_id: user.account_id)
    else
      where(account_id: user.account_id, company_id: [nil, user.company_id])
    end
  }

  def shared?
    company_id.nil?
  end

  def visibility_label
    shared? ? 'Shared' : company&.name
  end

  private

  def normalize_fields
    self.email = email.to_s.strip.downcase
    self.name = name.strip if name.present?
    self.phone = phone.strip if phone.present?
  end

  def company_belongs_to_account
    return if company_id.blank?
    return unless company.blank? || company.account_id != account_id

    errors.add(:company, 'must belong to the same account')
  end
end
