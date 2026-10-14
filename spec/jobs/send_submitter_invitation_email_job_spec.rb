# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe SendSubmitterInvitationEmailJob, type: :job do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:author) { create(:user, account:, company:) }
  let(:template) { create(:template, account:, company:, author:, name: 'HR Onboarding') }
  let(:submission) { create(:submission, account:, company:, template:) }
  let(:submitter_uuid) { submission.template_submitters.first.fetch('uuid') }
  let(:submitter) do
    create(
      :submitter,
      submission:,
      account:,
      company:,
      uuid: submitter_uuid,
      name: 'CHS Contact',
      email: 'contact.chs@example.com'
    )
  end

  describe '#perform' do
    let(:mail_double) { instance_double(ActionMailer::MessageDelivery, deliver_now!: true) }

    before do
      allow(SubmitterMailer).to receive(:invitation_email).with(submitter).and_return(mail_double)
      allow(Submitters::ValidateSending).to receive(:call).with(submitter, mail_double)
    end

    it 'creates SubmissionEvent send_email and ActivityEvent submission.email_sent with System actor snapshot' do
      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(SubmissionEvent, :count).by(1)
         .and change(ActivityEvent.where(action: 'submission.email_sent'), :count).by(1)

      submission_event = SubmissionEvent.last
      expect(submission_event.event_type).to eq('send_email')
      expect(submission_event.submitter_id).to eq(submitter.id)

      activity_event = ActivityEvent.where(action: 'submission.email_sent').last
      expect(activity_event.actor_user_id).to be_nil
      expect(activity_event.actor_name).to eq('System')
      expect(activity_event.actor_email).to be_nil
      expect(activity_event.subject_type).to eq('Submission')
      expect(activity_event.subject_id).to eq(submission.id)
      expect(activity_event.subject_label).to eq("HR Onboarding ##{submission.id}")
      expect(activity_event.company_id).to eq(company.id)
      expect(activity_event.visibility_scope).to eq('company')
      expect(activity_event.account_id).to eq(account.id)

      expect(activity_event.metadata['submitter_id']).to eq(submitter.id)
      expect(activity_event.metadata['submitter_uuid']).to eq(submitter.uuid)
      expect(activity_event.metadata['recipient_name']).to eq('CHS Contact')
      expect(activity_event.metadata['recipient_email']).to eq('contact.chs@example.com')
      expect(activity_event.metadata['submission_event_id']).to eq(submission_event.id)

      expect(activity_event.metadata.keys).not_to include('body', 'content', 'token', 'smtp', 'fields')
    end

    it 'does NOT create ActivityEvent or SubmissionEvent when mail delivery fails' do
      allow(mail_double).to receive(:deliver_now!).and_raise(StandardError, 'SMTP Delivery Failed')

      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to raise_error(StandardError, 'SMTP Delivery Failed')
         .and not_change(SubmissionEvent, :count)
         .and not_change(ActivityEvent, :count)
    end

    it 'creates separate ActivityEvents for distinct resend deliveries' do
      described_class.new.perform('submitter_id' => submitter.id)
      first_event = ActivityEvent.where(action: 'submission.email_sent').last
      expect(first_event).to be_present

      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(SubmissionEvent, :count).by(1)
         .and change(ActivityEvent.where(action: 'submission.email_sent'), :count).by(1)

      second_event = ActivityEvent.where(action: 'submission.email_sent').last
      expect(second_event.id).not_to eq(first_event.id)
      expect(second_event.metadata['submission_event_id']).not_to eq(first_event.metadata['submission_event_id'])
    end

    it 'is idempotent when record_submission_email! is called twice with the same SubmissionEvent' do
      described_class.new.perform('submitter_id' => submitter.id)
      submission_event = SubmissionEvent.last

      expect do
        result = ActivityEvents.record_submission_email!(
          submitter:,
          submission_event:,
          email_type: :invitation
        )
        expect(result).to be_nil
      end.not_to change(ActivityEvent, :count)
    end

    it 'handles submitter without name falling back gracefully in metadata' do
      submitter.update!(name: nil)

      described_class.new.perform('submitter_id' => submitter.id)
      activity_event = ActivityEvent.where(action: 'submission.email_sent').last

      expect(activity_event.metadata['recipient_name']).to be_nil
      expect(activity_event.metadata['recipient_email']).to eq('contact.chs@example.com')
    end

    it 'supports viewer submitters' do
      allow(submitter).to receive(:viewer?).and_return(true)
      allow(SubmitterMailer).to receive(:invitation_view_email).with(submitter).and_return(mail_double)

      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(ActivityEvent.where(action: 'submission.email_sent'), :count).by(1)
    end

    it 'enforces multi-tenancy: visible only to current company admin, not other company admin' do
      described_class.new.perform('submitter_id' => submitter.id)
      event = ActivityEvent.where(action: 'submission.email_sent').last

      chs_admin = create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false)
      md_admin = create(:user, account:, company: other_company, role: User::ADMIN_ROLE, platform_admin: false)
      platform_admin = create(:user, account:, company: other_company, role: User::ADMIN_ROLE, platform_admin: true)

      expect(ActivityEvent.visible_to(chs_admin)).to include(event)
      expect(ActivityEvent.visible_to(md_admin)).not_to include(event)
      expect(ActivityEvent.visible_to(platform_admin)).to include(event)
    end

    it 'does NOT fail the job or resend email when ActivityEvents mirror raises unexpectedly' do
      allow(ActivityEvents).to receive(:record_submission_email!).and_raise(StandardError, 'Activity Mirror DB Error')

      if defined?(Rollbar)
        allow(Rollbar).to receive(:error)
      else
        allow(Rails.logger).to receive(:error)
      end

      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.not_to raise_error

      expect(SubmitterMailer).to have_received(:invitation_email).with(submitter).once
      expect(Submitters::ValidateSending).to have_received(:call).with(submitter, mail_double).once

      expect(SubmissionEvent.where(submitter_id: submitter.id, event_type: 'send_email')).to exist
      expect(ActivityEvent.where(action: 'submission.email_sent')).to be_empty

      if defined?(Rollbar)
        expect(Rollbar).to have_received(:error).with(
          instance_of(StandardError),
          'Failed to create submission.email_sent ActivityEvent',
          submitter_id: submitter.id,
          submission_event_id: instance_of(Integer)
        )
      else
        expect(Rails.logger).to have_received(:error).with(/Failed to create submission.email_sent ActivityEvent/)
      end

      expect(submitter.reload.sent_at).to be_present
    end
  end
end
