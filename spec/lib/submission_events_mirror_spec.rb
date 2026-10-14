# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe SubmissionEvents do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:author) { create(:user, account:, company:) }
  let(:template) { create(:template, account:, company:, author:, name: 'HR Onboarding') }
  let(:submission) { create(:submission, account:, company:, template:) }
  let(:submitter) do
    create(
      :submitter,
      submission:,
      account:,
      company:,
      name: 'John Smith',
      email: 'john.smith@example.com'
    )
  end

  let(:request) do
    instance_double(
      ActionDispatch::Request,
      remote_ip: '203.0.113.195',
      user_agent: 'Mozilla/5.0 TestSigner',
      session: instance_double(ActionDispatch::Request::Session, id: 'sess_123'),
      env: { 'warden' => instance_double(Warden::Proxy, user: nil) }
    )
  end

  describe 'Central bridge in SubmissionEvents.create_with_tracking_data' do
    %w[view_form start_form complete_form decline_form delegate_form].each do |event_type|
      it "mirrors #{event_type} to corresponding ActivityEvent" do
        mapped_action = ActivityEvents::SUBMITTER_EVENT_ACTIONS[event_type]

        expect do
          described_class.create_with_tracking_data(submitter, event_type, request)
        end.to change(SubmissionEvent, :count).by(1)
           .and change(ActivityEvent.where(action: mapped_action), :count).by(1)

        submission_event = SubmissionEvent.last
        activity_event = ActivityEvent.where(action: mapped_action).last

        expect(submission_event.event_type).to eq(event_type)
        expect(submission_event.submitter_id).to eq(submitter.id)

        expect(activity_event.actor_user_id).to be_nil
        expect(activity_event.actor_name).to eq('John Smith')
        expect(activity_event.actor_email).to eq('john.smith@example.com')
        expect(activity_event.subject_type).to eq('Submission')
        expect(activity_event.subject_id).to eq(submission.id)
        expect(activity_event.subject_label).to eq("HR Onboarding ##{submission.id}")
        expect(activity_event.company_id).to eq(company.id)
        expect(activity_event.visibility_scope).to eq('company')
        expect(activity_event.metadata['submitter_id']).to eq(submitter.id)
        expect(activity_event.metadata['submission_event_id']).to eq(submission_event.id)
        expect(activity_event.metadata['ip']).to eq('203.0.113.195')
        expect(activity_event.metadata['user_agent']).to eq('Mozilla/5.0 TestSigner')
      end
    end

    %w[send_email send_reminder_email click_email click_sms email_verified invite_party].each do |technical_event|
      it "does NOT mirror technical event #{technical_event} to ActivityEvent" do
        expect do
          described_class.create_with_tracking_data(submitter, technical_event, request)
        end.to change(SubmissionEvent, :count).by(1)
           .and not_change(ActivityEvent, :count)
      end
    end

    it 'deduplicates repeated view_form ActivityEvents while keeping all SubmissionEvents' do
      # First view
      expect do
        described_class.create_with_tracking_data(submitter, 'view_form', request)
      end.to change(SubmissionEvent, :count).by(1)
         .and change(ActivityEvent.where(action: 'submitter.viewed_form'), :count).by(1)

      # Second view (e.g. page refresh)
      expect do
        described_class.create_with_tracking_data(submitter, 'view_form', request)
      end.to change(SubmissionEvent, :count).by(1)
         .and not_change(ActivityEvent, :count)

      expect(SubmissionEvent.where(submitter_id: submitter.id, event_type: 'view_form').count).to eq(2)
      expect(ActivityEvent.where(action: 'submitter.viewed_form', subject_id: submission.id).count).to eq(1)
    end

    it 'records separate completion events for multi-party submissions' do
      submitter2 = create(
        :submitter,
        submission:,
        account:,
        company:,
        name: 'Alice Cooper',
        email: 'alice@example.com'
      )

      expect do
        described_class.create_with_tracking_data(submitter, 'complete_form', request)
      end.to change(ActivityEvent.where(action: 'submitter.completed_form'), :count).by(1)

      expect do
        described_class.create_with_tracking_data(submitter2, 'complete_form', request)
      end.to change(ActivityEvent.where(action: 'submitter.completed_form'), :count).by(1)

      events = ActivityEvent.where(action: 'submitter.completed_form', subject_id: submission.id).order(:id)
      expect(events.size).to eq(2)

      expect(events.first.actor_name).to eq('John Smith')
      expect(events.first.actor_email).to eq('john.smith@example.com')
      expect(events.first.metadata['submitter_id']).to eq(submitter.id)

      expect(events.second.actor_name).to eq('Alice Cooper')
      expect(events.second.actor_email).to eq('alice@example.com')
      expect(events.second.metadata['submitter_id']).to eq(submitter2.id)
    end
  end
end
