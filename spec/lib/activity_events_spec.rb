# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityEvents do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:actor) { create(:user, account:, company:, first_name: 'John', last_name: 'Doe') }

  describe '.record!' do
    it 'records an event with actor snapshots and derived subject info' do
      recipient = create(:recipient_contact, account:, company:, name: 'Jane Smith', email: 'jane@example.com')

      event = described_class.record!(
        actor:,
        action: 'recipient_contact.created',
        subject: recipient
      )

      expect(event).to be_persisted
      expect(event.account_id).to eq(account.id)
      expect(event.company_id).to eq(company.id)
      expect(event.actor_user_id).to eq(actor.id)
      expect(event.actor_name).to eq('John Doe')
      expect(event.actor_email).to eq(actor.email)
      expect(event.action).to eq('recipient_contact.created')
      expect(event.subject_type).to eq('RecipientContact')
      expect(event.subject_id).to eq(recipient.id)
      expect(event.subject_label).to eq('Jane Smith <jane@example.com>')
      expect(event.visibility_scope).to eq('company')
    end

    it 'preserves actor and subject snapshot even if they are renamed later' do
      recipient = create(:recipient_contact, account:, company:, name: 'Original Name', email: 'orig@example.com')

      event = described_class.record!(
        actor:,
        action: 'recipient_contact.created',
        subject: recipient
      )

      # Rename actor and recipient
      actor.update!(first_name: 'Renamed', last_name: 'User', email: 'renamed@example.com')
      recipient.update!(name: 'New Name', email: 'new@example.com')

      event.reload
      expect(event.actor_name).to eq('John Doe')
      expect(event.actor_email).not_to eq('renamed@example.com')
      expect(event.subject_label).to eq('Original Name <orig@example.com>')
    end

    it 'persists and preserves history if subject is deleted' do
      recipient = create(:recipient_contact, account:, company:, name: 'Doomed Contact', email: 'bye@example.com')

      event = described_class.record!(
        actor:,
        action: 'recipient_contact.deleted',
        subject: recipient
      )

      recipient.destroy!
      event.reload

      expect(event).to be_persisted
      expect(event.subject_label).to eq('Doomed Contact <bye@example.com>')
      expect(event.visibility_scope).to eq('company')
    end

    it 'scopes shared RecipientContact to account visibility' do
      shared_recipient = create(
        :recipient_contact, :shared,
        account:, name: 'Shared Contact', email: 'shared@example.com'
      )

      event = described_class.record!(
        actor:,
        action: 'recipient_contact.created',
        subject: shared_recipient
      )

      expect(event.visibility_scope).to eq('account')
      expect(event.company_id).to be_nil
    end

    it 'scopes template to company visibility based on template company_id' do
      template = create(:template, account:, company:, author: actor)

      event = described_class.record!(
        actor:,
        action: 'template.created',
        subject: template
      )

      expect(event.visibility_scope).to eq('company')
      expect(event.company_id).to eq(company.id)
      expect(event.subject_label).to eq(template.name)
    end

    it 'scopes submission to company visibility based on submission company_id' do
      template = create(:template, account:, company:, author: actor)
      submission = create(:submission, account:, company:, template:)

      event = described_class.record!(
        actor:,
        action: 'submission.created',
        subject: submission
      )

      expect(event.visibility_scope).to eq('company')
      expect(event.company_id).to eq(company.id)
      expect(event.subject_label).to eq("#{template.name} ##{submission.id}")
    end

    it 'captures request ip and user_agent if request is passed' do
      recipient = create(:recipient_contact, account:, company:)
      request = instance_double(ActionDispatch::Request, remote_ip: '192.168.1.100', user_agent: 'RSpec Browser')

      event = described_class.record!(
        actor:,
        action: 'recipient_contact.updated',
        subject: recipient,
        request:,
        metadata: { changed_fields: ['name'] }
      )

      expect(event.metadata['ip']).to eq('192.168.1.100')
      expect(event.metadata['user_agent']).to eq('RSpec Browser')
      expect(event.metadata['changed_fields']).to eq(['name'])
    end
  end

  describe '.recent_for' do
    let(:platform_admin) { create(:user, account:, company:, platform_admin: true) }
    let(:company_admin) { create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false) }
    let(:editor) { create(:user, account:, company:, role: User::EDITOR_ROLE, platform_admin: false) }

    before do
      10.times do |i|
        described_class.record!(
          actor: platform_admin,
          action: 'recipient_contact.created',
          subject_label: "Contact #{i}",
          subject_type: 'RecipientContact',
          subject_id: i + 1,
          account_id: account.id,
          company_id: company.id,
          visibility_scope: 'company',
          occurred_at: (10 - i).minutes.ago
        )
      end
    end

    it 'returns up to 8 newest events for platform admin' do
      events = described_class.recent_for(platform_admin, limit: 8)
      expect(events.size).to eq(8)
      expect(events.first.subject_label).to eq('Contact 9')
    end

    it 'returns up to 8 events for company admin' do
      events = described_class.recent_for(company_admin, limit: 8)
      expect(events.size).to eq(8)
    end

    it 'returns none for editor' do
      expect(described_class.recent_for(editor)).to be_empty
    end
  end

  describe '.record_submitter_event!' do
    let(:template) { create(:template, account:, company:, author: actor, name: 'Form A') }
    let(:submission) { create(:submission, account:, company:, template:) }
    let(:submitter) do
      create(:submitter, submission:, account:, company:, name: 'Signer One', email: 'one@example.com')
    end

    it 'records submitter lifecycle events with derived submission subject and signer actor snapshots' do
      event = described_class.record_submitter_event!(submitter:, event_type: 'complete_form')

      expect(event).to be_persisted
      expect(event.action).to eq('submitter.completed_form')
      expect(event.actor_user_id).to be_nil
      expect(event.actor_name).to eq('Signer One')
      expect(event.actor_email).to eq('one@example.com')
      expect(event.subject_type).to eq('Submission')
      expect(event.subject_id).to eq(submission.id)
      expect(event.subject_label).to eq("Form A ##{submission.id}")
      expect(event.company_id).to eq(company.id)
      expect(event.visibility_scope).to eq('company')
      expect(event.metadata['submitter_id']).to eq(submitter.id)
      expect(event.metadata['submitter_uuid']).to eq(submitter.uuid)
    end

    it 'falls back to email or Recipient when submitter name is blank' do
      submitter.update!(name: nil)
      event = described_class.record_submitter_event!(submitter:, event_type: 'start_form')
      expect(event.actor_name).to eq('one@example.com')

      submitter2 = create(:submitter, submission:, account:, company:, name: nil, email: nil)
      event2 = described_class.record_submitter_event!(submitter: submitter2, event_type: 'start_form')
      expect(event2.actor_name).to eq('Recipient')
    end

    it 'returns nil and does not record an event for unapproved event types' do
      expect do
        event = described_class.record_submitter_event!(submitter:, event_type: 'send_email')
        expect(event).to be_nil
      end.not_to change(ActivityEvent, :count)
    end

    it 'is idempotent and returns nil if event already exists for submitter' do
      first_event = described_class.record_submitter_event!(submitter:, event_type: 'view_form')
      expect(first_event).to be_persisted

      duplicate_event = described_class.record_submitter_event!(submitter:, event_type: 'view_form')
      expect(duplicate_event).to be_nil
      expect(ActivityEvent.where(action: 'submitter.viewed_form', subject_id: submission.id).count).to eq(1)
    end
  end

  describe '.record_submission_email!' do
    let(:template) { create(:template, account:, company:, author: actor, name: 'Form A') }
    let(:submission) { create(:submission, account:, company:, template:) }
    let(:submitter) do
      create(:submitter, submission:, account:, company:, name: 'Signer One', email: 'one@example.com')
    end
    let(:submission_event) { SubmissionEvent.create!(submitter:, event_type: 'send_email') }

    it 'records invitation email event with System actor and recipient metadata' do
      event = described_class.record_submission_email!(
        submitter:,
        submission_event:,
        email_type: :invitation
      )

      expect(event).to be_persisted
      expect(event.action).to eq('submission.email_sent')
      expect(event.actor_user_id).to be_nil
      expect(event.actor_name).to eq('System')
      expect(event.actor_email).to be_nil
      expect(event.subject_type).to eq('Submission')
      expect(event.subject_id).to eq(submission.id)
      expect(event.subject_label).to eq("Form A ##{submission.id}")
      expect(event.company_id).to eq(company.id)
      expect(event.visibility_scope).to eq('company')
      expect(event.metadata['submitter_id']).to eq(submitter.id)
      expect(event.metadata['recipient_name']).to eq('Signer One')
      expect(event.metadata['recipient_email']).to eq('one@example.com')
      expect(event.metadata['submission_event_id']).to eq(submission_event.id)
    end

    it 'records reminder email event with slot and duration' do
      reminder_event = SubmissionEvent.create!(
        submitter:,
        event_type: 'send_reminder_email',
        data: { 'slot' => 'first_duration', 'duration' => 'two_days' }
      )

      event = described_class.record_submission_email!(
        submitter:,
        submission_event: reminder_event,
        email_type: :reminder,
        metadata: { 'slot' => 'first_duration', 'duration' => 'two_days' }
      )

      expect(event).to be_persisted
      expect(event.action).to eq('submission.reminder_email_sent')
      expect(event.metadata['slot']).to eq('first_duration')
      expect(event.metadata['duration']).to eq('two_days')
    end

    it 'is idempotent and returns nil when called with the same submission_event' do
      first_event = described_class.record_submission_email!(
        submitter:,
        submission_event:,
        email_type: :invitation
      )
      expect(first_event).to be_persisted

      duplicate = described_class.record_submission_email!(
        submitter:,
        submission_event:,
        email_type: :invitation
      )
      expect(duplicate).to be_nil
    end

    it 'returns nil for invalid email_type' do
      expect do
        result = described_class.record_submission_email!(
          submitter:,
          submission_event:,
          email_type: :open_email
        )
        expect(result).to be_nil
      end.not_to change(ActivityEvent, :count)
    end
  end
end
