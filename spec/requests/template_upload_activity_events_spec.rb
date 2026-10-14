# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Upload Activity Events', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:admin) do
    create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false)
  end
  let(:uploaded_pdf) do
    fixture_file_upload(Rails.root.join('spec/fixtures/sample-document.pdf'), 'application/pdf')
  end

  before { login_as(admin, scope: :user) }

  describe 'POST /templates_upload' do
    it 'creates a template and records exactly one template.created ActivityEvent' do
      expect do
        post templates_upload_path, params: {
          files: [uploaded_pdf]
        }
      end.to change(ActivityEvent.where(action: 'template.created'), :count).by(1)

      template = Template.last
      expect(response).to redirect_to(edit_template_path(template))

      event = ActivityEvent.where(action: 'template.created').last
      expect(event.subject_id).to eq(template.id)
      expect(event.subject_label).to eq(template.name)
      expect(event.actor_user_id).to eq(admin.id)
      expect(event.company_id).to eq(company.id)
      expect(event.visibility_scope).to eq('company')
    end

    it 'does NOT record ActivityEvent when attachment creation raises PdfEncrypted' do
      allow(Templates::CreateAttachments).to receive(:call).and_raise(Templates::CreateAttachments::PdfEncrypted)

      expect do
        post templates_upload_path, params: {
          files: [uploaded_pdf],
          form_id: 'upload_form'
        }
      end.not_to change(ActivityEvent, :count)
    end

    it 'does NOT record ActivityEvent when an unexpected StandardError is encountered' do
      allow(Templates::CreateAttachments).to receive(:call).and_raise(StandardError, 'Upload processing failed')

      expect do
        post templates_upload_path, params: {
          files: [uploaded_pdf]
        }
      rescue StandardError
        # local env might re-raise StandardError
      end.not_to change(ActivityEvent, :count)
    end
  end
end
