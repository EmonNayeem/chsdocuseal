# frozen_string_literal: true

# == Schema Information
#
# Table name: submitter_reminder_deliveries
#
#  id           :bigint           not null, primary key
#  due_at       :datetime         not null
#  duration_key :string           not null
#  sent_at      :datetime
#  slot         :string           not null
#  status       :string           default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  company_id   :bigint           not null
#  submitter_id :bigint           not null
#
# Indexes
#
#  index_submitter_reminder_deliveries_on_account_id             (account_id)
#  index_submitter_reminder_deliveries_on_company_id             (company_id)
#  index_submitter_reminder_deliveries_on_submitter_id           (submitter_id)
#  index_submitter_reminder_deliveries_on_submitter_id_and_slot  (submitter_id,slot) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (company_id => companies.id)
#  fk_rails_...  (submitter_id => submitters.id)
#
class SubmitterReminderDelivery < ApplicationRecord
  belongs_to :submitter
  belongs_to :account
  belongs_to :company

  validates :slot, presence: true
  validates :duration_key, presence: true
  validates :due_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending sent failed] }
  validates :slot, uniqueness: { scope: :submitter_id }
end
