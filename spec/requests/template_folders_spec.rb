# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Folders', type: :request do
  let(:account) { create(:account) }
  let(:company) { Company.create!(name: 'Company 1', code: 'C1', account: account) }
  let(:other_company) { Company.create!(name: 'Company 2', code: 'C2', account: account) }
  let(:user) { create(:user, company: company, account: account, role: 'viewer') }

  before do
    sign_in user
    user.update!(role: 'viewer')
  end

  describe 'POST /folders' do
    context 'when user is a platform admin' do
      before { user.update!(platform_admin: true, role: 'admin') }

      it 'creates folder in the selected company' do
        expect do
          post folders_path, params: { template_folder: { name: 'New Folder', company_id: other_company.id } }
        end.to change(TemplateFolder, :count).by(1)

        expect(response).to redirect_to(folder_path(TemplateFolder.last))
        expect(TemplateFolder.last.company_id).to eq(other_company.id)
        expect(TemplateFolder.last.name).to eq('New Folder')
      end

      it 'creates folder in own company if company_id is not provided' do
        expect do
          post folders_path, params: { template_folder: { name: 'New Folder' } }
        end.to change(TemplateFolder, :count).by(1)

        expect(response).to redirect_to(folder_path(TemplateFolder.last))
        expect(TemplateFolder.last.company_id).to eq(company.id)
      end
    end

    context 'when user is a company admin' do
      before { user.update!(platform_admin: false, role: 'admin') }

      it 'creates folder in own company' do
        expect do
          post folders_path, params: { template_folder: { name: 'New Folder' } }
        end.to change(TemplateFolder, :count).by(1)

        expect(response).to redirect_to(folder_path(TemplateFolder.last))
        expect(TemplateFolder.last.company_id).to eq(company.id)
      end

      it 'cannot create folder in another company by sending company_id' do
        expect do
          post folders_path, params: { template_folder: { name: 'Hacked Folder', company_id: other_company.id } }
        end.not_to change(TemplateFolder, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is a viewer' do
      it 'cannot create folder' do
        expect do
          post folders_path, params: { template_folder: { name: 'New Folder' } }
        end.not_to change(TemplateFolder, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'DELETE /folders/:id' do
    let!(:folder) { create(:template_folder, name: 'My Folder', company: company, account: account) }

    context 'when user is a platform admin' do
      before { user.update!(platform_admin: true, role: 'admin') }

      it 'can delete empty folder' do
        expect do
          delete folder_path(folder)
        end.to change(TemplateFolder.active, :count).by(-1)

        expect(response).to redirect_to(templates_path)
        expect(flash[:notice]).to match(/Folder deleted successfully/)
      end

      it 'cannot delete non-empty folder (has templates) without confirmation' do
        create(:template, folder: folder, company: company, account: account, author: user)

        expect do
          delete folder_path(folder)
        end.not_to change(TemplateFolder.active, :count)

        expect(response).to redirect_to(folder_path(folder))
        expect(flash[:alert]).to match(/Folder contains templates or subfolders/)
      end

      it 'can delete non-empty folder (has templates) with confirmation' do
        create(:template, folder: folder, company: company, account: account, author: user)

        expect do
          delete folder_path(folder, destroy_contents: true)
        end.to change(TemplateFolder.active, :count).by(-1)
           .and change(Template.active, :count).by(-1)

        expect(response).to redirect_to(templates_path)
        expect(flash[:notice]).to match(/Folder deleted successfully/)
      end

      it 'cannot delete non-empty folder (has subfolders) without confirmation' do
        create(:template_folder, parent_folder: folder, company: company, account: account)

        expect do
          delete folder_path(folder)
        end.not_to change(TemplateFolder.active, :count)

        expect(response).to redirect_to(folder_path(folder))
        expect(flash[:alert]).to match(/Folder contains templates or subfolders/)
      end

      it 'can delete non-empty folder (has subfolders) with confirmation' do
        create(:template_folder, parent_folder: folder, company: company, account: account)

        expect do
          delete folder_path(folder, destroy_contents: true)
        end.to change(TemplateFolder.active, :count).by(-2)

        expect(response).to redirect_to(templates_path)
        expect(flash[:notice]).to match(/Folder deleted successfully/)
      end
    end

    context 'when user is a company admin' do
      before { user.update!(platform_admin: false, role: 'admin') }

      it 'can delete own empty folder' do
        expect do
          delete folder_path(folder)
        end.to change(TemplateFolder.active, :count).by(-1)

        expect(response).to redirect_to(templates_path)
        expect(flash[:notice]).to match(/Folder deleted successfully/)
      end

      it 'cannot delete another companys folder' do
        other_folder = create(:template_folder, company: other_company, account: account)

        expect do
          delete folder_path(other_folder)
        end.not_to change(TemplateFolder.active, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is a viewer' do
      it 'cannot delete folder' do
        expect do
          delete folder_path(folder)
        end.not_to change(TemplateFolder.active, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
