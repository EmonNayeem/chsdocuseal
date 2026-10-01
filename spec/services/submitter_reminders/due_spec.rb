# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterReminders::Due, type: :module do
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

  before do
    AccountConfig.create!(
      account: account,
      key: AccountConfig::SUBMITTER_REMINDERS,
      value: {
        'first_duration' => 'two_days',
        'second_duration' => 'four_days',
        'third_duration' => 'eight_days',
        'enabled_at' => 10.days.ago.utc.iso8601,
        'invalid_duration' => 'foo'
      }
    )
  end

  describe '.due_at' do
    it 'calculates first_duration correctly from sent_at' do
      expect(described_class.due_at(submitter, 'first_duration')).to eq(submitter.sent_at + 2.days)
    end

    it 'calculates second_duration correctly from sent_at' do
      expect(described_class.due_at(submitter, 'second_duration')).to eq(submitter.sent_at + 4.days)
    end

    it 'calculates third_duration correctly from sent_at' do
      expect(described_class.due_at(submitter, 'third_duration')).to eq(submitter.sent_at + 8.days)
    end

    it 'returns nil for absent slot' do
      expect(described_class.due_at(submitter, 'fourth_duration')).to be_nil
    end

    it 'returns nil for invalid duration safely ignored' do
      expect(described_class.due_at(submitter, 'invalid_duration')).to be_nil
    end

    it 'adding enabled_at does not affect duration calculations' do
      config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
      config.update!(value: config.value.merge('enabled_at' => Time.current.utc.iso8601))
      expect(described_class.due_at(submitter, 'first_duration')).to eq(submitter.sent_at + 2.days)
    end
  end

  describe '.eligible?' do
    context 'when enforcing the rollout cutoff' do
      let(:config) { account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS) }

      it 'is ineligible if sent_at is BEFORE enabled_at' do
        config.update!(value: config.value.merge('enabled_at' => 1.day.ago.utc.iso8601))
        submitter.update!(sent_at: 2.days.ago)
        expect(described_class.eligible?(submitter)).to be false
      end

      it 'is eligible if sent_at is EXACTLY AT enabled_at' do
        time = Time.current.beginning_of_minute
        config.update!(value: config.value.merge('enabled_at' => time.utc.iso8601))
        submitter.update!(sent_at: time)
        expect(described_class.eligible?(submitter)).to be true
      end

      it 'is eligible if sent_at is AFTER enabled_at' do
        config.update!(value: config.value.merge('enabled_at' => 3.days.ago.utc.iso8601))
        submitter.update!(sent_at: 2.days.ago)
        expect(described_class.eligible?(submitter)).to be true
      end

      it 'is ineligible if missing enabled_at (fails closed)' do
        config.update!(value: config.value.except('enabled_at'))
        expect(described_class.eligible?(submitter)).to be false
      end

      it 'is ineligible if malformed enabled_at (fails closed without crashing)' do
        config.update!(value: config.value.merge('enabled_at' => 'not-a-date'))
        expect(described_class.eligible?(submitter)).to be false
      end

      it 'is ineligible if non-string enabled_at (fails closed without crashing)' do
        config.update!(value: config.value.merge('enabled_at' => 123))
        expect(described_class.eligible?(submitter)).to be false
      end

      it 'blank/invalid duration schedule is considered disabled' do
        expect(described_class.schedule_enabled?({})).to be false
        expect(described_class.schedule_enabled?({ 'first_duration' => 'invalid_key' })).to be false
        expect(described_class.schedule_enabled?({ 'first_duration' => '' })).to be false
        expect(described_class.schedule_enabled?({ 'first_duration' => 'one_hour' })).to be true
      end

      it 'is ineligible if config has enabled_at BUT no valid duration slots' do
        config.update!(value: { 'enabled_at' => 10.days.ago.utc.iso8601, 'first_duration' => 'invalid_value' })
        expect(described_class.eligible?(submitter)).to be false
      end
    end

    it 'is eligible when all conditions are met (current eligible signer)' do
      expect(described_class.eligible?(submitter)).to be true
    end

    it 'is skipped if completed' do
      submitter.update!(completed_at: Time.current)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if declined' do
      submitter.update!(declined_at: Time.current)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if viewer using real viewer structure' do
      submission.update!(
        template_submitters: [
          {
            'uuid' => submitter.uuid,
            'name' => 'Viewer',
            'is_viewer' => true
          }
        ]
      )
      expect(submitter.viewer?).to be true
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if submission is archived' do
      submission.update!(archived_at: Time.current)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if submission is expired' do
      allow(submission).to receive(:expired?).and_return(true)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if template is archived' do
      template.update!(archived_at: Time.current)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if no email' do
      submitter.update!(email: '')
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if send_email false' do
      submitter.preferences['send_email'] = false
      submitter.save!
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if no sent_at' do
      submitter.update!(sent_at: nil)
      expect(described_class.eligible?(submitter)).to be false
    end

    it 'is skipped if not current signing order' do
      allow(Submitters).to receive(:current_submitter_order?).with(submitter).and_return(false)
      expect(described_class.eligible?(submitter)).to be false
    end
  end
end
