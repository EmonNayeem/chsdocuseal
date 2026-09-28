# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Templates Preferences Reset', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user, submitter_count: 3) }

  let(:employee_uuid) { template.submitters[0]['uuid'] }
  let(:manager_uuid) { template.submitters[1]['uuid'] }
  let(:ict_uuid) { template.submitters[2]['uuid'] }

  before do
    login_as(user, scope: :user)
  end

  describe 'DELETE /templates/:id/preferences' do
    context 'with general template email and per-party emails' do
      before do
        template.update!(
          preferences: {
            'request_email_subject' => 'General Subject',
            'request_email_body' => 'General Body',
            'submitters' => [
              {
                'uuid' => employee_uuid,
                'request_email_subject' => 'Emp Subject',
                'request_email_body' => 'Emp Body'
              },
              {
                'uuid' => manager_uuid,
                'request_email_subject' => 'Mgr Subject',
                'request_email_body' => 'Mgr Body',
                'some_future_setting' => 'keep-me'
              }
            ]
          }
        )
      end

      it 'resets general email only when scope=general is provided' do
        delete template_preferences_path(template), params: {
          config_key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
          scope: 'general'
        }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        template.reload
        expect(template.preferences['request_email_subject']).to be_nil
        expect(template.preferences['request_email_body']).to be_nil

        employee_pref = template.preferences['submitters'].find { |s| s['uuid'] == employee_uuid }
        expect(employee_pref['request_email_subject']).to eq('Emp Subject')

        manager_pref = template.preferences['submitters'].find { |s| s['uuid'] == manager_uuid }
        expect(manager_pref['request_email_subject']).to eq('Mgr Subject')
      end

      it 'resets only the specified party when submitter_uuid is provided' do
        delete template_preferences_path(template), params: {
          config_key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
          submitter_uuid: manager_uuid
        }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        template.reload
        expect(template.preferences['request_email_subject']).to eq('General Subject')

        employee_pref = template.preferences['submitters'].find { |s| s['uuid'] == employee_uuid }
        expect(employee_pref['request_email_subject']).to eq('Emp Subject')

        manager_pref = template.preferences['submitters'].find { |s| s['uuid'] == manager_uuid }
        expect(manager_pref['request_email_subject']).to be_nil
        expect(manager_pref['request_email_body']).to be_nil
        expect(manager_pref['some_future_setting']).to eq('keep-me')
      end

      it 'ignores unknown submitter UUIDs' do
        delete template_preferences_path(template), params: {
          config_key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
          submitter_uuid: 'fake-uuid'
        }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        template.reload
        expect(template.preferences['request_email_subject']).to eq('General Subject')
        expect(template.preferences['submitters'].size).to eq(2)
      end

      it 'is harmless when resetting party with no override' do
        delete template_preferences_path(template), params: {
          config_key: AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY,
          submitter_uuid: ict_uuid
        }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        template.reload
        expect(template.preferences['request_email_subject']).to eq('General Subject')
        expect(template.preferences['submitters'].size).to eq(2)
      end
    end
  end
end
