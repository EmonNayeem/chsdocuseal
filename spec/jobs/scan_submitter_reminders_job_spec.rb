# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanSubmitterRemindersJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user) }
  let(:submission) { create(:submission, template: template, account: account) }
  let(:token) { 'my-scheduler-token' }

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
    allow(SubmitterReminders::NextDueSlot).to receive(:call).and_return(nil)
    allow(SendSubmitterReminderEmailJob).to receive(:perform_async)
    allow(described_class).to receive(:perform_in)
  end

  context 'when scanner does not own the lease (different token)' do
    before do
      allow(SubmitterReminders::ScannerLease).to receive(:verify_or_acquire!).with(token).and_return(false)
    end

    it 'different token owns lease -> old scanner returns -> does NOT scan -> does NOT schedule next run' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')

      described_class.new.perform('scheduler_token' => token)

      expect(SubmitterReminders::NextDueSlot).not_to have_received(:call)
      expect(SendSubmitterReminderEmailJob).not_to have_received(:perform_async)
      expect(described_class).not_to have_received(:perform_in)
    end
  end

  context 'when scanner owns the lease (same token)' do
    before do
      allow(SubmitterReminders::ScannerLease).to receive(:verify_or_acquire!).with(token).and_return(true)
    end

    it 'ownership success allows scanning' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')

      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).once
      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end

    it 'enqueues exactly one worker job if candidate has due slot and schedules next run with SAME token' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')

      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
        'submitter_id' => submitter.id,
        'slot' => 'first_duration'
      ).once

      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end

    it 'enqueues none if submitter is ineligible and still schedules next run with SAME token' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return(nil)

      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).not_to have_received(:perform_async)
      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end

    it 'successful scan with zero candidates still schedules next run with SAME token' do
      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).not_to have_received(:perform_async)
      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end

    it 'candidate/worker enqueue failure: exception propagates -> perform_in not called' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')
      allow(SendSubmitterReminderEmailJob).to receive(:perform_async).and_raise(StandardError, 'Redis unavailable')

      expect do
        described_class.new.perform('scheduler_token' => token)
      end.to raise_error(StandardError, 'Redis unavailable')

      expect(described_class).not_to have_received(:perform_in)
    end

    it 'filters obviously impossible candidates in DB scope (Phase 2B restored coverage)' do
      create(
        :submitter,
        submission: submission,
        uuid: 'no-email',
        sent_at: 2.days.ago,
        email: nil
      )
      create(
        :submitter,
        submission: submission,
        uuid: 'completed',
        sent_at: 2.days.ago,
        email: 'a@b.com',
        completed_at: Time.current
      )
      create(
        :submitter,
        submission: submission,
        uuid: 'declined',
        sent_at: 2.days.ago,
        email: 'a@b.com',
        declined_at: Time.current
      )
      create(
        :submitter,
        submission: submission,
        uuid: 'not-sent',
        sent_at: nil,
        email: 'a@b.com'
      )

      described_class.new.perform('scheduler_token' => token)

      expect(SubmitterReminders::NextDueSlot).not_to have_received(:call)
      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end

    it 'handles multiple eligible candidate submitters, schedules exactly once (Phase 2B restored coverage)' do
      submitter1 = submitter
      submitter2 = create(
        :submitter,
        submission: submission,
        uuid: 'another-uuid',
        sent_at: 3.days.ago,
        email: 'test2@example.com'
      )

      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter1).and_return('first_duration')
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter2).and_return('second_duration')

      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
        'submitter_id' => submitter1.id,
        'slot' => 'first_duration'
      ).once

      expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
        'submitter_id' => submitter2.id,
        'slot' => 'second_duration'
      ).once

      expect(described_class).to have_received(:perform_in)
        .with(described_class::SCAN_INTERVAL, 'scheduler_token' => token).once
    end
  end

  context 'when lease is lost during scan' do
    it 'ownership lost after scan but before reschedule -> old chain does not schedule another copy' do
      submitter # create candidate
      allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')

      # Mock the lease ownership check to succeed the first time, but fail the second time
      allow(SubmitterReminders::ScannerLease).to receive(:verify_or_acquire!)
        .with(token).and_return(true, false)

      described_class.new.perform('scheduler_token' => token)

      expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).once
      expect(described_class).not_to have_received(:perform_in)
    end
  end

  context 'when no token is provided' do
    it 'returns without scanning or scheduling' do
      submitter
      described_class.new.perform({})

      expect(SubmitterReminders::NextDueSlot).not_to have_received(:call)
      expect(described_class).not_to have_received(:perform_in)
    end
  end
end
