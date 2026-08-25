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

      expect(mail.subject).to eq('Materials Direct document request')
      expect(mail.body.encoded).to include('Materials Direct has sent you a document to review and complete.')
    end

    it 'falls back to CHS defaults for unknown company' do
      unknown = Company.find_by(code: 'UNKNOWN') || Company.create!(name: 'UNKNOWN', code: 'UNKNOWN', account: account)
      template.update!(company: unknown)
      mail = described_class.invitation_email(submitter)

      expect(mail.subject).to eq('Churchfield Home Services document request')
      expect(mail.body.encoded).to include('Churchfield Home Services has sent you a document to review and complete.')
    end

    it 'overrides company defaults with custom template preferences' do
      template.update!(
        preferences: { 'request_email_subject' => 'Custom Subject', 'request_email_body' => 'Custom Body' }
      )
      mail = described_class.invitation_email(submitter)

      expect(mail.subject).to eq('Custom Subject')
      expect(mail.body.encoded).to include('Custom Body')
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
end
