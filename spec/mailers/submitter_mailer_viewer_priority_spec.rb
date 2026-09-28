# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterMailer, type: :mailer do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user, submitter_count: 2) }

  let(:manager_uuid) { template.submitters[1]['uuid'] }
  let(:submission) do
    s = create(:submission, account: account, template: template, created_by_user: user)
    s.update!(
      template_submitters: [
        { 'uuid' => template.submitters[0]['uuid'] },
        { 'uuid' => manager_uuid, 'is_viewer' => true }
      ]
    )
    s
  end

  let!(:manager) { create(:submitter, submission: submission, uuid: manager_uuid, email: 'mgr@example.com') }

  before do
    # Account/Global Viewer Invitation Email
    config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_VIEW_INVITATION_EMAIL_KEY)
    config.value = { 'subject' => 'Global Viewer Subject', 'body' => 'Global Viewer Body' }
    config.save!

    # Template-level Viewer Invitation Email
    template.update!(
      preferences: {
        'invitation_view_email_subject' => 'Template Viewer Subject',
        'invitation_view_email_body' => 'Template Viewer Body',
        'submitters' => [
          {
            'uuid' => manager_uuid,
            'request_email_subject' => 'Per-Party Viewer Subject',
            'request_email_body' => 'Per-Party Viewer Body'
          }
        ]
      }
    )
  end

  describe '#invitation_view_email' do
    it 'prioritizes per-party override over template-level viewer default' do
      expect(manager.viewer?).to be true

      mail = described_class.invitation_view_email(manager)

      expect(mail.subject).to eq('Per-Party Viewer Subject')
      expect(mail.body.encoded).to include('Per-Party Viewer Body')
    end

    it 'prioritizes one-off custom EmailMessage over per-party' do
      email_message = EmailMessage.create!(
        account: account,
        author: user,
        subject: 'One-off Subject',
        body: 'One-off Body'
      )
      manager.update!(preferences: { 'email_message_uuid' => email_message.uuid })

      mail = described_class.invitation_view_email(manager)

      expect(mail.subject).to eq('One-off Subject')
      expect(mail.body.encoded).to include('One-off Body')
    end

    it 'falls back to template-level viewer default when per-party is absent' do
      template.update!(
        preferences: {
          'invitation_view_email_subject' => 'Template Viewer Subject',
          'invitation_view_email_body' => 'Template Viewer Body'
        }
      )

      mail = described_class.invitation_view_email(manager)

      expect(mail.subject).to eq('Template Viewer Subject')
      expect(mail.body.encoded).to include('Template Viewer Body')
    end

    it 'falls back to account/global viewer config when template-level is absent' do
      template.update!(preferences: {})

      mail = described_class.invitation_view_email(manager)

      expect(mail.subject).to eq('Global Viewer Subject')
      expect(mail.body.encoded).to include('Global Viewer Body')

      config = AccountConfigs.find_for_account(account, AccountConfig::SUBMITTER_VIEW_INVITATION_EMAIL_KEY)
      config.update!(value: {})

      mail = described_class.invitation_view_email(manager)

      company = CompanyEmailDefaults.company_for_submitter(manager)
      expect(mail.subject).to eq(CompanyEmailDefaults.invitation_subject(company))
      expect(mail.body.encoded).to include(CompanyEmailDefaults.invitation_body(company).split("\n")[2].strip)
    end
  end
end
