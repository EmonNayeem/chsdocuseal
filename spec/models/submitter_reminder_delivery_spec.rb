# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterReminderDelivery, type: :model do
  describe 'validations' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }
    let(:template) { create(:template, account: account, author: user) }
    let(:submission) { create(:submission, template: template, account: account) }

    let(:submitter_uuid) { submission.template_submitters.first.fetch('uuid') }
    let(:submitter) do
      create(
        :submitter,
        submission: submission,
        uuid: submitter_uuid,
        sent_at: 2.days.ago,
        email: 'test@example.com'
      )
    end

    let(:delivery) do
      described_class.new(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: Time.current,
        status: 'pending'
      )
    end

    it 'is valid with valid attributes' do
      expect(delivery).to be_valid
    end

    it 'requires a slot' do
      delivery.slot = nil
      expect(delivery).not_to be_valid
    end

    it 'requires a duration_key' do
      delivery.duration_key = nil
      expect(delivery).not_to be_valid
    end

    it 'requires a due_at' do
      delivery.due_at = nil
      expect(delivery).not_to be_valid
    end

    it 'requires a company' do
      delivery.company = nil
      expect(delivery).not_to be_valid
    end

    it 'validates status inclusion' do
      delivery.status = 'unknown'
      expect(delivery).not_to be_valid
      delivery.status = 'sent'
      expect(delivery).to be_valid
    end

    it 'validates uniqueness of slot per submitter' do
      delivery.save!
      duplicate = delivery.dup
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations cleanup' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }
    let(:template) { create(:template, account: account, author: user) }
    let(:submission) { create(:submission, template: template, account: account) }

    let(:submitter_uuid) { submission.template_submitters.first.fetch('uuid') }
    let(:submitter) do
      create(
        :submitter,
        submission: submission,
        uuid: submitter_uuid,
        sent_at: 2.days.ago,
        email: 'test@example.com'
      )
    end

    it 'destroys delivery claims when submitter is destroyed' do
      delivery = described_class.create!(
        submitter: submitter,
        account: account,
        company: submitter.company,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: Time.current,
        status: 'pending'
      )

      expect { submitter.destroy }.to change(described_class, :count).by(-1)
      expect(described_class.find_by(id: delivery.id)).to be_nil
    end
  end
end
