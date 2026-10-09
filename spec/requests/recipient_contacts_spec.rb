# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RecipientContacts', type: :request do
  let(:account) { create(:account) }
  let(:chs_company) { account.companies.find_by!(code: 'CHS') }
  let(:md_company) { account.companies.find_by!(code: 'MD') }

  let!(:shared_contact) { create(:recipient_contact, account: account, company: nil) }
  let!(:chs_contact) { create(:recipient_contact, account: account, company: chs_company) }
  let!(:md_contact) { create(:recipient_contact, account: account, company: md_company) }

  describe 'Platform Admin' do
    let(:admin) do
      create(
        :user,
        account: account,
        company: chs_company,
        role: User::ADMIN_ROLE,
        platform_admin: true
      )
    end

    before do
      login_as(admin, scope: :user)
    end

    it 'can list all contacts in account' do
      get settings_recipient_contacts_path
      expect(response).to be_successful
      expect(response.body).to include(shared_contact.email)
      expect(response.body).to include(chs_contact.email)
      expect(response.body).to include(md_contact.email)
    end

    it 'can render new form' do
      get new_settings_recipient_contact_path
      expect(response).to be_successful
      expect(response.body).to include('New Recipient')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).not_to include('<submit-form>')
    end

    it 'can render edit form' do
      get edit_settings_recipient_contact_path(chs_contact)
      expect(response).to be_successful
      expect(response.body).to include('Edit Recipient')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).not_to include('<submit-form>')
    end

    it 'can create Shared contact' do
      post settings_recipient_contacts_path, params: {
        recipient_contact: { name: 'New Shared', email: 'new.shared@example.com', company_id: '' }
      }
      expect(response).to redirect_to(settings_recipient_contacts_path)

      contact = RecipientContact.find_by(email: 'new.shared@example.com')
      expect(contact.company_id).to be_nil
    end

    it 'can create company recipient' do
      post settings_recipient_contacts_path, params: {
        recipient_contact: { name: 'New C1', email: 'new.c1@example.com', company_id: chs_company.id }
      }
      expect(response).to redirect_to(settings_recipient_contacts_path)

      contact = RecipientContact.find_by(email: 'new.c1@example.com')
      expect(contact.company_id).to eq(chs_company.id)
    end

    it 'can edit visibility' do
      patch settings_recipient_contact_path(shared_contact), params: {
        recipient_contact: { company_id: chs_company.id }
      }
      expect(shared_contact.reload.company_id).to eq(chs_company.id)
    end

    it 'can delete' do
      expect do
        delete settings_recipient_contact_path(chs_contact)
      end.to change(RecipientContact, :count).by(-1)
    end
  end

  describe 'Company Admin' do
    let(:admin) do
      create(
        :user,
        account: account,
        company: chs_company,
        role: User::ADMIN_ROLE
      )
    end

    before do
      login_as(admin, scope: :user)
    end

    it 'index sees own Company + Shared, NOT other Company' do
      get settings_recipient_contacts_path
      expect(response).to be_successful
      expect(response.body).to include(shared_contact.email)
      expect(response.body).to include(chs_contact.email)
      expect(response.body).not_to include(md_contact.email)
    end

    it 'can render new form' do
      get new_settings_recipient_contact_path
      expect(response).to be_successful
      expect(response.body).to include('New Recipient')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).not_to include('<submit-form>')
    end

    it 'can render edit form for own company contact' do
      get edit_settings_recipient_contact_path(chs_contact)
      expect(response).to be_successful
      expect(response.body).to include('Edit Recipient')
      expect(response.body).to include('data-turbo-frame="_top"')
      expect(response.body).not_to include('<submit-form>')
    end

    it 'can create own Company contact, malicious company_id is forced to own' do
      post settings_recipient_contacts_path, params: {
        recipient_contact: { name: 'Malicious', email: 'mal@example.com', company_id: md_company.id }
      }
      expect(response).to redirect_to(settings_recipient_contacts_path)

      contact = RecipientContact.find_by(email: 'mal@example.com')
      expect(contact.company_id).to eq(chs_company.id)
    end

    it 'can edit own Company contact' do
      patch settings_recipient_contact_path(chs_contact), params: {
        recipient_contact: { name: 'Updated' }
      }
      expect(chs_contact.reload.name).to eq('Updated')
    end

    it 'cannot edit Shared contact' do
      patch settings_recipient_contact_path(shared_contact), params: {
        recipient_contact: { name: 'Hacked' }
      }
      expect(response).to redirect_to(root_path)
      expect(shared_contact.reload.name).not_to eq('Hacked')
    end

    it 'cannot delete Shared contact' do
      delete settings_recipient_contact_path(shared_contact)
      expect(response).to redirect_to(root_path)
    end

    it 'cannot edit another Company contact' do
      expect do
        patch settings_recipient_contact_path(md_contact), params: {
          recipient_contact: { name: 'Hacked' }
        }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'Editor' do
    let(:editor) do
      create(
        :user,
        account: account,
        company: chs_company,
        role: User::EDITOR_ROLE
      )
    end

    before do
      login_as(editor, scope: :user)
    end

    it 'cannot access the index' do
      get settings_recipient_contacts_path
      expect(response).to redirect_to(root_path)
    end

    it 'cannot create contacts' do
      post settings_recipient_contacts_path, params: {
        recipient_contact: { name: 'Hacked', email: 'hack@example.com' }
      }
      expect(response).to redirect_to(root_path)
    end
  end
end
