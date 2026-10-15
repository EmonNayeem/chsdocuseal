# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Templates Versions API', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:admin) { create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false) }
  let(:other_admin) { create(:user, account:, company: other_company, role: User::ADMIN_ROLE, platform_admin: false) }
  let(:template) { create(:template, account:, company:, author: admin) }

  before { login_as(admin, scope: :user) }

  describe 'GET /templates/:template_id/versions' do
    it 'returns versions list ordered newest first with version numbers' do
      v1 = TemplateVersions.find_or_create_for(template, author: admin)

      template.name = 'V2 Name'
      template.save!
      v2 = TemplateVersions.find_or_create_for(template, author: admin)

      get template_versions_path(template)
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.size).to eq(2)
      expect(json.first['id']).to eq(v2.id)
      expect(json.first['version_number']).to eq(2)
      expect(json.second['id']).to eq(v1.id)
      expect(json.second['version_number']).to eq(1)
    end
  end

  describe 'POST /templates/:template_id/versions' do
    it 'creates a new version on explicit save and deduplicates identical snapshot' do
      expect do
        post template_versions_path(template)
      end.to change(template.template_versions, :count).by(1)
      expect(response).to have_http_status(:ok)

      expect do
        post template_versions_path(template)
      end.not_to change(template.template_versions, :count)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /templates/:template_id/versions/:id/compare' do
    it 'returns structured comparison and visual payload between version and current template' do
      version = TemplateVersions.find_or_create_for(template, author: admin)
      template.update!(name: 'Changed Name')

      get compare_template_version_path(template, version)
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['identical']).to be(false)
      expect(json['name']['changed']).to be(true)
      expect(json['version_number']).to eq(1)
      expect(json['visual']).to be_present
      expect(json['visual']['historical']).to be_present
      expect(json['visual']['current']).to be_present
      expect(json['visual']['historical']['name']).to eq(version.data['name'])
      expect(json['visual']['current']['name']).to eq('Changed Name')
    end
  end

  describe 'POST /templates/:template_id/versions/:id/restore' do
    it 'restores template state and records ActivityEvent' do
      version = TemplateVersions.find_or_create_for(template, author: admin)
      original_name = template.name

      template.update!(name: 'Mutated Name')

      expect do
        post restore_template_version_path(template, version)
      end.to change(ActivityEvent.where(action: 'template.version_restored'), :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be(true)
      expect(template.reload.name).to eq(original_name)
    end
  end

  describe 'POST /templates/:template_id/versions/:id/copy' do
    it 'creates a new copied template from version snapshot' do
      version = TemplateVersions.find_or_create_for(template, author: admin)

      expect do
        post copy_template_version_path(template, version), params: { name: 'My Custom Copy' }
      end.to change(Template, :count).by(1)

      expect(response).to have_http_status(:ok)
      new_template = Template.last
      expect(new_template.name).to eq('My Custom Copy')
      expect(new_template.company_id).to eq(company.id)
    end
  end

  describe 'GET /templates/:template_id/versions/:id/documents' do
    it 'returns document proxy URLs for the historical version' do
      version = TemplateVersions.find_or_create_for(template, author: admin)

      get documents_template_version_path(template, version)
      expect(response).to have_http_status(:ok)

      urls = response.parsed_body
      expect(urls).to be_an(Array)
      expect(urls.first).to include('/file/')
    end

    it 'returns 404 if version belongs to a different template' do
      other_template = create(:template, account:, company:, author: admin)
      other_version = TemplateVersions.find_or_create_for(other_template, author: admin)

      get documents_template_version_path(template, other_version)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Template Show Page Entry Point' do
    it 'renders Version History shortcut for authorized user' do
      get template_path(template)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('template-revisions-modal')
      expect(response.body).to include('Version History')
      expect(response.body).to include(template.id.to_s)
    end

    it 'does not render Version History shortcut when template is archived' do
      template.update!(archived_at: Time.current)

      get template_path(template)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('template-revisions-modal')
      expect(response.body).not_to include('Version History')
    end

    it 'does not render Version History shortcut for a viewer without update permission' do
      department = Department.create!(name: 'HR', company:, account:)
      template.departments << department
      viewer = create(:user, account:, company:, role: User::VIEWER_ROLE,
                             platform_admin: false, departments: [department])
      login_as(viewer, scope: :user)

      get template_path(template)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('template-revisions-modal')
      expect(response.body).not_to include('Version History')
    end
  end

  describe 'Authorization & Tenancy' do
    let(:version) { TemplateVersions.find_or_create_for(template, author: admin) }

    it 'denies access to an admin from another company' do
      login_as(other_admin, scope: :user)

      get template_versions_path(template), as: :json
      expect(response).to have_http_status(:forbidden)

      get compare_template_version_path(template, version), as: :json
      expect(response).to have_http_status(:forbidden)

      post restore_template_version_path(template, version), as: :json
      expect(response).to have_http_status(:forbidden)

      post copy_template_version_path(template, version), as: :json
      expect(response).to have_http_status(:forbidden)

      get documents_template_version_path(template, version), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
