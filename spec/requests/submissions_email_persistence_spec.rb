# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Submissions Email Persistence', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user, submitter_count: 3) }

  before do
    login_as(user, scope: :user)
  end

  describe 'POST /templates/:id/submissions' do
    let(:employee_uuid) { template.submitters[0]['uuid'] }
    let(:manager_uuid) { template.submitters[1]['uuid'] }
    let(:ict_uuid) { template.submitters[2]['uuid'] }

    context 'when save_message is checked and per-party is enabled' do
      it 'persists per-party messages correctly by UUID without altering unrelated' do
        template.update!(
          preferences: {
            'submitters' => [
              { 'uuid' => 'unrelated-uuid', 'request_email_subject' => 'Keep me' }
            ]
          }
        )

        post template_submissions_path(template), params: {
          save_message: '1',
          request_email_per_submitter: '1',
          submitter_preferences: {
            employee_uuid => { subject: 'Employee Subject', body: 'Employee Body' },
            manager_uuid => { subject: 'Manager Subject', body: 'Manager Body' },
            ict_uuid => { subject: 'ICT Subject', body: 'ICT Body' }
          },
          submission: {
            '0' => {
              submitters: [
                { uuid: employee_uuid, email: 'emp@example.com', name: 'Emp' },
                { uuid: manager_uuid, email: 'mgr@example.com', name: 'Mgr' },
                { uuid: ict_uuid, email: 'ict@example.com', name: 'ICT' }
              ]
            }
          }
        }

        template.reload

        expect(template.preferences['submitters'].size).to eq(4)

        employee_pref = template.preferences['submitters'].find { |s| s['uuid'] == employee_uuid }
        expect(employee_pref['request_email_subject']).to eq('Employee Subject')
        expect(employee_pref['request_email_body']).to eq('Employee Body')

        manager_pref = template.preferences['submitters'].find { |s| s['uuid'] == manager_uuid }
        expect(manager_pref['request_email_subject']).to eq('Manager Subject')

        unrelated_pref = template.preferences['submitters'].find { |s| s['uuid'] == 'unrelated-uuid' }
        expect(unrelated_pref['request_email_subject']).to eq('Keep me')
      end
    end

    context 'when save_message is checked but per-party is NOT enabled' do
      it 'persists general template message only' do
        post template_submissions_path(template), params: {
          save_message: '1',
          subject: 'General Subject',
          body: 'General Body',
          submission: {
            '0' => {
              submitters: [
                { uuid: employee_uuid, email: 'emp@example.com', name: 'Emp' }
              ]
            }
          }
        }

        template.reload
        expect(template.preferences['request_email_subject']).to eq('General Subject')
        expect(template.preferences['request_email_body']).to eq('General Body')
        expect(template.preferences['submitters']).to be_nil
      end
    end

    context 'when save_message is NOT checked' do
      it 'does not alter template preferences' do
        post template_submissions_path(template), params: {
          save_message: '0',
          subject: 'One-off Subject',
          submission: {
            '0' => {
              submitters: [
                { uuid: employee_uuid, email: 'emp@example.com', name: 'Emp' }
              ]
            }
          }
        }

        template.reload
        expect(template.preferences['request_email_subject']).to be_nil
      end
    end
  end
end
