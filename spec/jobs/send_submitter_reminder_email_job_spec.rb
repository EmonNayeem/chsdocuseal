# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSubmitterReminderEmailJob, type: :job do
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
        'enabled_at' => 10.days.ago.utc.iso8601
      }
    )
  end

  describe 'claim behavior' do
    it 'A. existing sent claim: no email, no new event' do
      SubmitterReminderDelivery.create!(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: 1.day.ago,
        status: 'sent',
        sent_at: 1.day.ago
      )

      allow(SubmitterMailer).to receive(:reminder_email)

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.not_to change(SubmissionEvent, :count)

      expect(SubmitterMailer).not_to have_received(:reminder_email)
    end

    it 'B. existing non-stale pending claim: no email, worker returns' do
      SubmitterReminderDelivery.create!(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: 1.day.ago,
        status: 'pending'
      )

      allow(SubmitterMailer).to receive(:reminder_email)

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.not_to change(SubmissionEvent, :count)

      expect(SubmitterMailer).not_to have_received(:reminder_email)
    end

    it 'C. failed claim: retry atomically reclaims, sends once, becomes sent' do
      claim = SubmitterReminderDelivery.create!(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: 1.day.ago,
        status: 'failed'
      )

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to change(SubmissionEvent, :count).by(1)

      expect(claim.reload.status).to eq('sent')
    end

    it 'D. two attempts to reclaim same failed claim: conditional claim mechanism means only one can own it' do
      claim = SubmitterReminderDelivery.create!(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: 1.day.ago,
        status: 'failed'
      )

      # simulate that another worker already updated it
      SubmitterReminderDelivery.where(id: claim.id).update_all(status: 'pending', updated_at: Time.current)

      allow(SubmitterMailer).to receive(:reminder_email)

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.not_to change(SubmissionEvent, :count)

      expect(SubmitterMailer).not_to have_received(:reminder_email)
    end

    it 'E. stale pending: can be reclaimed once' do
      claim = SubmitterReminderDelivery.create!(
        submitter: submitter,
        account: account,
        company_id: submitter.company_id,
        slot: 'first_duration',
        duration_key: 'two_days',
        due_at: 1.day.ago,
        status: 'pending',
        updated_at: 20.minutes.ago
      )

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to change(SubmissionEvent, :count).by(1)

      expect(claim.reload.status).to eq('sent')
    end

    it 'F. mailer construction raises: claim becomes failed, exception re-raised' do
      allow(SubmitterMailer).to receive(:reminder_email).and_raise(StandardError, 'Mailer Error')

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to raise_error(StandardError, 'Mailer Error')

      expect(SubmitterReminderDelivery.last.status).to eq('failed')
    end

    it 'G. ValidateSending raises: claim becomes failed, exception re-raised' do
      mail_double = instance_double(ActionMailer::MessageDelivery)
      allow(SubmitterMailer).to receive(:reminder_email).and_return(mail_double)
      allow(Submitters::ValidateSending).to receive(:call).and_raise(StandardError, 'Validation Error')

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to raise_error(StandardError, 'Validation Error')

      expect(SubmitterReminderDelivery.last.status).to eq('failed')
    end

    it 'H. deliver_now! raises: claim becomes failed, exception re-raised' do
      mail_double = instance_double(ActionMailer::MessageDelivery)
      allow(SubmitterMailer).to receive(:reminder_email).and_return(mail_double)
      allow(Submitters::ValidateSending).to receive(:call)
      allow(mail_double).to receive(:deliver_now!).and_raise(StandardError, 'SMTP Error')

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to raise_error(StandardError, 'SMTP Error')

      expect(SubmitterReminderDelivery.last.status).to eq('failed')
    end

    it 'I. successful send: claim sent, sent_at present, exactly one event with correct data' do
      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.to change(SubmissionEvent, :count).by(1)

      claim = SubmitterReminderDelivery.last
      expect(claim.status).to eq('sent')
      expect(claim.sent_at).to be_present

      event = SubmissionEvent.last
      expect(event.event_type).to eq('send_reminder_email')
      expect(event.data['slot']).to eq('first_duration')
      expect(event.data['duration']).to eq('two_days')
    end

    it 'keeps a sent claim when audit event creation fails and does not resend' do
      mail_double = instance_double(ActionMailer::MessageDelivery, deliver_now!: true)
      allow(SubmitterMailer).to receive(:reminder_email).with(submitter).and_return(mail_double)
      allow(Submitters::ValidateSending).to receive(:call).with(submitter, mail_double)

      allow(SubmissionEvent).to receive(:create!).and_raise(StandardError, 'Audit Error')

      if defined?(Rollbar)
        allow(Rollbar).to receive(:error)
      else
        allow(Rails.logger).to receive(:error)
      end

      expect do
        described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      end.not_to raise_error

      expect(SubmitterMailer).to have_received(:reminder_email).with(submitter).once
      expect(Submitters::ValidateSending).to have_received(:call).with(submitter, mail_double).once

      if defined?(Rollbar)
        expect(Rollbar).to have_received(:error).with(
          instance_of(StandardError),
          'Failed to create send_reminder_email SubmissionEvent',
          submitter_id: submitter.id
        )
      else
        expect(Rails.logger).to have_received(:error).with(/Failed to create send_reminder_email SubmissionEvent/)
      end

      claim = SubmitterReminderDelivery.last
      expect(claim.status).to eq('sent')
      expect(claim.sent_at).to be_present

      # Attempt second time, it should NOT resend
      described_class.new.perform('submitter_id' => submitter.id, 'slot' => 'first_duration')
      expect(SubmitterMailer).to have_received(:reminder_email).with(submitter).once
    end
  end
end
