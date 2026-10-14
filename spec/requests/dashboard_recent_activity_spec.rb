# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard Recent Activity', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:admin) do
    create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: true)
  end
  let(:editor) do
    create(:user, account:, company:, role: User::EDITOR_ROLE, platform_admin: false)
  end

  before do
    ActivityEvents.record!(
      actor: admin,
      action: 'recipient_contact.created',
      subject_label: 'Recent Recipient <recent@example.com>',
      subject_type: 'RecipientContact',
      subject_id: 1,
      account_id: account.id,
      company_id: company.id,
      visibility_scope: 'company',
      occurred_at: 5.minutes.ago
    )

    ActivityEvents.record!(
      actor: nil,
      actor_user_id: nil,
      actor_name: 'John Smith',
      actor_email: 'john@example.com',
      action: 'submitter.completed_form',
      subject_label: 'NDA Form #42',
      subject_type: 'Submission',
      subject_id: 42,
      account_id: account.id,
      company_id: company.id,
      visibility_scope: 'company',
      occurred_at: 2.minutes.ago
    )

    ActivityEvents.record!(
      actor: nil,
      actor_user_id: nil,
      actor_name: 'System',
      actor_email: nil,
      action: 'submission.email_sent',
      subject_label: 'NDA Form #42',
      subject_type: 'Submission',
      subject_id: 42,
      account_id: account.id,
      company_id: company.id,
      visibility_scope: 'company',
      metadata: {
        'recipient_name' => 'CHS Contact',
        'recipient_email' => 'contact.chs@example.com'
      },
      occurred_at: 1.minute.ago
    )
  end

  describe 'Templates Dashboard' do
    it 'renders Recent Activity for admin' do
      login_as(admin, scope: :user)
      get templates_path
      expect(response).to be_successful
      expect(response.body).to include('Recent Activity')
      expect(response.body).to include('Recent Recipient')
      expect(response.body).to include('John Smith')
      expect(response.body).to include('completed submission')
      expect(response.body).to include('System')
      expect(response.body).to include('sent signature request email to')
      expect(response.body).to include('CHS Contact')
      expect(response.body).to include('NDA Form #42')
    end

    it 'does NOT render Recent Activity for editor' do
      login_as(editor, scope: :user)
      get templates_path
      expect(response).to be_successful
      expect(response.body).not_to include('Recent Activity')
      expect(response.body).not_to include('Recent Recipient')
    end
  end

  describe 'Submissions Dashboard' do
    it 'renders Recent Activity for admin' do
      login_as(admin, scope: :user)
      get submissions_path
      expect(response).to be_successful
      expect(response.body).to include('Recent Activity')
      expect(response.body).to include('Recent Recipient')
    end

    it 'does NOT render Recent Activity for editor' do
      login_as(editor, scope: :user)
      get submissions_path
      expect(response).to be_successful
      expect(response.body).not_to include('Recent Activity')
      expect(response.body).not_to include('Recent Recipient')
    end
  end
end
