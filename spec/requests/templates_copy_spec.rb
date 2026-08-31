# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Templates Copy UI', type: :request do
  let(:account) { create(:account) }
  let(:company) { Company.create!(name: 'Company 1', code: 'C1', account: account) }
  let(:user) { create(:user, company: company, account: account, role: 'viewer') }
  let!(:template) { create(:template, company: company, account: account, author: user) }
  let(:target_company) { Company.create!(name: 'Company 2', code: 'C2', account: account) }

  before do
    sign_in user
    user.update!(role: 'viewer')
  end

  describe 'GET /templates/:template_id/copy/new' do
    context 'when user is a platform admin' do
      before do
        user.update!(platform_admin: true, role: 'admin')
      end

      it 'allows access' do
        get new_template_copy_path(template)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is a company admin' do
      before do
        user.update!(platform_admin: false, role: 'admin')
      end

      it 'allows access to own company template' do
        get new_template_copy_path(template)
        expect(response).to have_http_status(:success)
      end

      it 'denies access to other company template' do
        other_account = create(:account)
        other_user = create(:user, account: other_account)
        other_template = create(:template, account: other_account, author: other_user)
        get new_template_copy_path(other_template)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is a viewer' do
      it 'denies access' do
        get new_template_copy_path(template)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /templates/:template_id/copy' do
    context 'when user is a platform admin' do
      before do
        user.update!(platform_admin: true, role: 'admin')
      end

      it 'copies the template to any company' do
        expect do
          post template_copy_index_path(template),
               params: { company_id: target_company.id, template: { name: 'New Name' } }
        end.to change(Template, :count).by(1)

        expect(response).to redirect_to(edit_template_path(Template.last))
        expect(Template.last.company_id).to eq(target_company.id)
      end

      it 'copies the template with valid target_department_ids' do
        department = Department.create!(name: 'IT', company: target_company, account: account)

        expect do
          post template_copy_index_path(template),
               params: { company_id: target_company.id, department_ids: [department.id], template: { name: 'New' } }
        end.to change(Template, :count).by(1)

        expect(response).to redirect_to(edit_template_path(Template.last))
        expect(Template.last.department_ids).to include(department.id)
      end

      it 'copies the template with valid target_folder_id' do
        folder = create(:template_folder, company: target_company, account: account)

        expect do
          post template_copy_index_path(template),
               params: { company_id: target_company.id, folder_id: folder.id, template: { name: 'New Name' } }
        end.to change(Template, :count).by(1)

        expect(response).to redirect_to(edit_template_path(Template.last))
        expect(Template.last.folder_id).to eq(folder.id)
      end

      it 'rejects department from another company' do
        other_dept = Department.create!(name: 'HR', company: company, account: account)

        expect do
          post template_copy_index_path(template),
               params: { company_id: target_company.id, department_ids: [other_dept.id] }
        end.not_to change(Template, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to match(/belong to the target company/)
      end

      it 'rejects folder from another company' do
        other_folder = create(:template_folder, company: company, account: account)

        expect do
          post template_copy_index_path(template),
               params: { company_id: target_company.id, folder_id: other_folder.id }
        end.not_to change(Template, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to match(/belong to the target company/)
      end
    end

    context 'when user is a company admin' do
      before do
        user.update!(platform_admin: false, role: 'admin')
      end

      it 'copies the template to own company' do
        expect do
          post template_copy_index_path(template),
               params: { template: { name: 'New Name' } }
        end.to change(Template, :count).by(1)

        expect(response).to redirect_to(edit_template_path(Template.last))
        expect(Template.last.company_id).to eq(company.id)
      end

      it 'copies with valid same-company departments and folder' do
        department = Department.create!(name: 'HR', company: company, account: account)
        folder = create(:template_folder, company: company, account: account)

        expect do
          post template_copy_index_path(template),
               params: { department_ids: [department.id], folder_id: folder.id, template: { name: 'New' } }
        end.to change(Template, :count).by(1)

        expect(response).to redirect_to(edit_template_path(Template.last))
        expect(Template.last.department_ids).to include(department.id)
        expect(Template.last.folder_id).to eq(folder.id)
      end

      it 'ignores company_id param and copies to own company' do
        post template_copy_index_path(template),
             params: { company_id: target_company.id, template: { name: 'New Name' } }
        expect(Template.last.company_id).to eq(company.id)
      end
    end

    context 'when user is an editor' do
      before do
        user.update!(platform_admin: false, role: 'editor')
      end

      it 'cannot copy' do
        expect do
          post template_copy_index_path(template),
               params: { template: { name: 'New Name' } }
        end.not_to change(Template, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
