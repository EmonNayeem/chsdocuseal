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

  describe '.due_at' do
    before do
      AccountConfig.create!(
        account: account,
        key: AccountConfig::SUBMITTER_REMINDERS,
        value: {
          'first_duration' => 'two_days',
          'second_duration' => 'four_days',
          'third_duration' => 'eight_days',
          'invalid_duration' => 'foo'
        }
      )
    end

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
  end

  describe '.eligible?' do
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
