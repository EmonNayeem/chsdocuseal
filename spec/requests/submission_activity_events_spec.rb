# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Submission Activity Events', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:admin) do
    create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: true)
  end
  let(:template) { create(:template, account:, company:, author: admin) }

  before { login_as(admin, scope: :user) }

  describe 'Submission lifecycle activity logging' do
    it 'logs submission.created for each created submission in batch creation' do
      expect do
        post template_submissions_path(template), params: {
          emails: ['user1@example.com', 'user2@example.com']
        }
      end.to change(ActivityEvent.where(action: 'submission.created'), :count).by(2)

      events = ActivityEvent.where(action: 'submission.created').order(:id)
      expect(events.first.subject_label).to include(template.name)
      expect(events.first.actor_user_id).to eq(admin.id)
      expect(events.first.company_id).to eq(company.id)
      expect(events.first.metadata['source']).to eq('invite')
      expect(events.first.metadata['template_id']).to eq(template.id)
      expect(events.second.subject_label).to include(template.name)
    end

    it 'logs submission.archived on soft deletion' do
      submission = create(:submission, account:, company:, template:)

      expect do
        delete submission_path(submission)
      end.to change(ActivityEvent.where(action: 'submission.archived'), :count).by(1)

      event = ActivityEvent.where(action: 'submission.archived').last
      expect(event.subject_id).to eq(submission.id)
      expect(event.subject_label).to include(template.name)
    end

    it 'logs submission.deleted on permanent deletion and survives subject destroy' do
      submission = create(:submission, account:, company:, template:)
      sub_id = submission.id
      sub_label = "#{template.name} ##{sub_id}"

      expect do
        delete submission_path(submission), params: { permanently: 'true' }
      end.to change(ActivityEvent.where(action: 'submission.deleted'), :count).by(1)

      event = ActivityEvent.where(action: 'submission.deleted').last
      expect(event.subject_id).to eq(sub_id)
      expect(event.subject_label).to eq(sub_label)
      expect(Submission.find_by(id: sub_id)).to be_nil
    end
  end
end
