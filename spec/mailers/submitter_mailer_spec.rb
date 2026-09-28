# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterMailer, type: :mailer do
  describe 'invitation_email' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account: account) }
    let(:company) do
      Company.find_by(code: 'MD') || Company.create!(name: 'MD', code: 'MD', account: account)
    end
    let(:template) { create(:template, account: account, author: author, company: company) }
    let(:submission) { create(:submission, template: template, account: account) }
    let(:submitter) { create(:submitter, submission: submission, account: account, uuid: SecureRandom.uuid) }

    it 'uses company specific defaults when no custom values exist' do
      mail = described_class.invitation_email(submitter)

      company = CompanyEmailDefaults.company_for_submitter(submitter)
      expect(mail.subject).to eq(CompanyEmailDefaults.invitation_subject(company))
      expect(mail.body.encoded).to include(CompanyEmailDefaults.invitation_body(company).split("\n")[2].strip)
    end

    it 'falls back to CHS defaults for unknown company' do
      unknown = Company.find_by(code: 'UNKNOWN') || Company.create!(name: 'UNKNOWN', code: 'UNKNOWN', account: account)
      template.update!(company: unknown)
      mail = described_class.invitation_email(submitter)

      expect(mail.subject).to eq('Churchfield Home Services document request')
      expect(mail.body.encoded).to include('Churchfield Home Services has sent you a document to review and complete.')
    end

    it 'prioritizes account/global config over company default' do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY)
      config.value = { 'subject' => 'Global Signer Subject', 'body' => 'Global Signer Body' }
      config.save!

      mail = described_class.invitation_email(submitter)

      expect(mail.subject).to eq('Global Signer Subject')
      expect(mail.body.encoded).to include('Global Signer Body')

      config.update!(value: {})

      mail = described_class.invitation_email(submitter)

      company = CompanyEmailDefaults.company_for_submitter(submitter)
      expect(mail.subject).to eq(CompanyEmailDefaults.invitation_subject(company))
      expect(mail.body.encoded).to include(CompanyEmailDefaults.invitation_body(company).split("\n")[2].strip)
    end

    it 'overrides company defaults with custom template preferences' do
      template.update!(
        preferences: { 'request_email_subject' => 'Custom Subject', 'request_email_body' => 'Custom Body' }
      )
      mail = described_class.invitation_email(submitter)

      expect(mail.subject).to eq('Custom Subject')
      expect(mail.body.encoded).to include('Custom Body')
    end

    it 'suppresses the fallback link when body contains a tiptap malformed submitter.link' do
      template.update!(
        preferences: { 'request_email_body' => 'Click here: {[submitter.link](http://submitter.link)}' }
      )
      mail = described_class.invitation_email(submitter)

      # submitter.link is replaced with the URL, and MarkdownToHtml autolinks it, so it appears in href and text (2 times)
      expect(mail.body.encoded.scan(%r{/s/#{submitter.slug}}).size).to eq(2)
    end

    it 'appends the fallback link when body genuinely contains no link' do
      template.update!(
        preferences: { 'request_email_body' => 'Just some text without a link' }
      )
      mail = described_class.invitation_email(submitter)

      # The fallback link will be appended (link_to nil, url), so it appears in href and text (2 times)
      expect(mail.body.encoded.scan(%r{/s/#{submitter.slug}}).size).to eq(2)
    end
  end

  describe 'invitation_view_email' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account: account) }
    let(:company) do
      Company.find_by(code: 'ESS') || Company.create!(name: 'ESS', code: 'ESS', account: account)
    end
    let(:template) { create(:template, account: account, author: author, company: company) }
    let(:submission) { create(:submission, template: template, account: account) }
    let(:submitter) { create(:submitter, submission: submission, account: account, uuid: SecureRandom.uuid) }

    it 'uses company specific defaults when no custom values exist' do
      mail = described_class.invitation_view_email(submitter)

      expect(mail.subject).to eq('Efficient Software Solutions document request')
      expect(mail.body.encoded).to include(
        'Efficient Software Solutions has sent you a document to review and complete.'
      )
    end
  end

  describe 'completed_email' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account: account) }
    let(:company) do
      Company.find_by(code: 'MD') || Company.create!(name: 'MD', code: 'MD', account: account)
    end
    let(:first_uuid) { SecureRandom.uuid }
    let(:second_uuid) { SecureRandom.uuid }
    let(:template) do
      t = create(:template, account: account, author: author, company: company)
      t.update!(submitters: [{ 'uuid' => first_uuid, 'name' => 'Signer 1' },
                             { 'uuid' => second_uuid, 'name' => 'Signer 2' }])
      t
    end
    let(:submission) { create(:submission, template: template, account: account) }
    let(:submitter) do
      create(:submitter,
             submission: submission,
             account: account,
             uuid: first_uuid,
             name: 'John Doe',
             email: 'john@example.com')
    end

    before do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY)
      config.value = config.value.to_h.merge('attach_documents' => false, 'attach_audit_log' => false)
      config.value.delete('subject')
      config.value.delete('body')
      config.save!

      # Add a second submitter to test indexed variables
      create(:submitter,
             submission: submission,
             account: account,
             uuid: second_uuid,
             name: 'Jane Smith',
             email: 'jane@example.com',
             completed_at: Time.current)

      submitter.update!(completed_at: Time.current)
    end

    it 'uses company specific defaults when no custom values exist' do
      mail = described_class.completed_email(submitter, author)

      company = CompanyEmailDefaults.company_for_submitter(submitter)
      expect(mail.subject).to eq(CompanyEmailDefaults.completed_subject(company))
      expect(mail.body.encoded).to include('The document has been completed.')
      expect(mail.body.encoded).to include('Materials Direct')
      expected_url = Rails.application.routes.url_helpers.submission_url(
        submitter.submission,
        **Docuseal.default_url_options
      )
      expect(mail.body.encoded).to include(expected_url)
    end

    it 'falls back to CHS defaults for unknown company' do
      unknown = Company.find_by(code: 'UNKNOWN') || Company.create!(name: 'UNKNOWN', code: 'UNKNOWN', account: account)
      template.update!(company: unknown)
      mail = described_class.completed_email(submitter, author)

      expect(mail.subject).to eq('Churchfield Home Services document completed')
      expect(mail.body.encoded).to include('Churchfield Home Services')
    end

    it 'uses account config when available, beating company default' do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY)
      config.value = config.value.to_h.merge('subject' => 'Account Global Subject', 'body' => 'Account Global Body')
      config.save!

      mail = described_class.completed_email(submitter, author)

      expect(mail.subject).to eq('Account Global Subject')
      expect(mail.body.encoded).to include('Account Global Body')
    end

    it 'uses template preference, beating account config' do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_COMPLETED_EMAIL_KEY)
      config.value = config.value.to_h.merge('subject' => 'Account Global Subject', 'body' => 'Account Global Body')
      config.save!

      template.update!(preferences: {
                         'completed_notification_email_subject' => 'Template Subject',
                         'completed_notification_email_body' => 'Template Body'
                       })
      mail = described_class.completed_email(submitter, author)

      expect(mail.subject).to eq('Template Subject')
      expect(mail.body.encoded).to include('Template Body')
    end

    it 'resolves variables in custom body' do
      template.update!(preferences: {
                         'completed_notification_email_subject' => 'Custom',
                         'completed_notification_email_body' => '{submitters[1].name} {submitters[2].email}'
                       })
      mail = described_class.completed_email(submitter, author)

      expect(mail.body.encoded).to include('John Doe jane@example.com')
    end
  end

  describe 'documents_copy_email' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account: account) }
    let(:company) do
      Company.find_by(code: 'MD') || Company.create!(name: 'MD', code: 'MD', account: account)
    end
    let(:first_uuid) { SecureRandom.uuid }
    let(:second_uuid) { SecureRandom.uuid }
    let(:template) do
      t = create(:template, account: account, author: author, company: company)
      t.update!(submitters: [{ 'uuid' => first_uuid, 'name' => 'Signer 1' },
                             { 'uuid' => second_uuid, 'name' => 'Signer 2' }])
      t
    end
    let(:submission) { create(:submission, template: template, account: account) }
    let(:submitter) do
      create(:submitter,
             submission: submission,
             account: account,
             uuid: first_uuid,
             name: 'John Doe',
             email: 'john@example.com')
    end

    before do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY)
      config.value = config.value.to_h.merge('attach_documents' => false, 'attach_audit_log' => false)
      config.value.delete('subject')
      config.value.delete('body')
      config.save!

      create(:submitter,
             submission: submission,
             account: account,
             uuid: second_uuid,
             name: 'Jane Smith',
             email: 'jane@example.com',
             completed_at: Time.current)
      submitter.update!(completed_at: Time.current)
    end

    it 'uses company specific defaults when no custom values exist' do
      mail = described_class.documents_copy_email(submitter)

      company = CompanyEmailDefaults.company_for_submitter(submitter)
      expect(mail.subject).to eq(CompanyEmailDefaults.documents_copy_subject(company))
      expect(mail.body.encoded).to include('Your completed document copy is ready.')
      expect(mail.body.encoded).to include('Materials Direct')
      expect(mail.body.encoded).to include(submitter.submission.slug)

      # Test signed link behavior
      mail_with_sig = described_class.documents_copy_email(submitter, sig: true)
      expect(mail_with_sig.body.encoded).to include('sig=')
    end

    it 'falls back to CHS defaults for unknown company' do
      unknown = Company.find_by(code: 'UNKNOWN') || Company.create!(name: 'UNKNOWN', code: 'UNKNOWN', account: account)
      template.update!(company: unknown)
      mail = described_class.documents_copy_email(submitter)

      expect(mail.subject).to eq('Your Churchfield Home Services document copy')
      expect(mail.body.encoded).to include('Churchfield Home Services')
    end

    it 'uses account config when available, beating company default' do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY)
      config.value = config.value.to_h.merge('subject' => 'Global Copy Subject', 'body' => 'Global Copy Body')
      config.save!

      mail = described_class.documents_copy_email(submitter)

      expect(mail.subject).to eq('Global Copy Subject')
      expect(mail.body.encoded).to include('Global Copy Body')
    end

    it 'uses template preference, beating account config' do
      config = AccountConfigs.find_or_initialize_for_key(account, AccountConfig::SUBMITTER_DOCUMENTS_COPY_EMAIL_KEY)
      config.value = config.value.to_h.merge('subject' => 'Global Copy Subject', 'body' => 'Global Copy Body')
      config.save!

      template.update!(preferences: {
                         'documents_copy_email_subject' => 'Template Copy Subject',
                         'documents_copy_email_body' => 'Template Copy Body'
                       })
      mail = described_class.documents_copy_email(submitter)

      expect(mail.subject).to eq('Template Copy Subject')
      expect(mail.body.encoded).to include('Template Copy Body')
    end

    it 'resolves documents.link' do
      template.update!(preferences: {
                         'documents_copy_email_subject' => 'Copy',
                         'documents_copy_email_body' => '{documents.link}'
                       })
      mail = described_class.documents_copy_email(submitter)
      expect(mail.body.encoded).to include(submitter.submission.slug)
    end

    it 'resolves indexed party variables' do
      template.update!(preferences: {
                         'documents_copy_email_subject' => 'Copy',
                         'documents_copy_email_body' => '{submitters[1].name} {submitters[2].email}'
                       })
      mail = described_class.documents_copy_email(submitter)
      expect(mail.body.encoded).to include('John Doe jane@example.com')
    end
  end
end
