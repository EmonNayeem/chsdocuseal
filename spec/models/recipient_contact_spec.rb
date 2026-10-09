# frozen_string_literal: true

# == Schema Information
#
# Table name: recipient_contacts
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  name       :string
#  phone      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  company_id :bigint
#
# Indexes
#
#  index_recipient_contacts_on_account_id            (account_id)
#  index_recipient_contacts_on_account_id_and_email  (account_id,email) UNIQUE
#  index_recipient_contacts_on_company_id            (company_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (company_id => companies.id)
#
require 'rails_helper'

RSpec.describe RecipientContact, type: :model do
  describe 'validations' do
    let(:account) { create(:account) }

    it 'validates email presence' do
      contact = build(:recipient_contact, email: nil, account: account)
      expect(contact).not_to be_valid
      expect(contact.errors[:email]).to include("can't be blank")
    end

    it 'normalizes email and ensures uniqueness per account' do
      create(:recipient_contact, email: 'person@example.com', account: account)

      contact = build(:recipient_contact, email: ' Person@Example.COM ', account: account)
      contact.valid?

      expect(contact.email).to eq('person@example.com')
      expect(contact.errors[:email]).to include('has already been taken')
    end

    it 'allows same email in different accounts' do
      create(:recipient_contact, email: 'person@example.com', account: account)

      other_account = create(:account)
      contact = build(:recipient_contact, email: 'person@example.com', account: other_account)

      expect(contact).to be_valid
    end

    it 'rejects company/account mismatch' do
      other_account = create(:account)
      company = other_account.companies.find_by!(code: 'CHS')

      contact = build(:recipient_contact, account: account, company: company)
      expect(contact).not_to be_valid
      expect(contact.errors[:company]).to include('must belong to the same account')
    end

    it 'allows shared recipient (nil company_id)' do
      contact = build(:recipient_contact, account: account, company_id: nil)
      expect(contact).to be_valid
      expect(contact.shared?).to be true
    end
  end

  describe '.visible_to' do
    let(:account) { create(:account) }
    let(:chs_company) { account.companies.find_by!(code: 'CHS') }
    let(:md_company) { account.companies.find_by!(code: 'MD') }

    let!(:shared_contact) { create(:recipient_contact, account: account, company: nil) }
    let!(:chs_contact) { create(:recipient_contact, account: account, company: chs_company) }
    let!(:md_contact) { create(:recipient_contact, account: account, company: md_company) }

    it 'returns all account entries for platform admin' do
      user = create(
        :user,
        account: account,
        company: chs_company,
        role: User::ADMIN_ROLE,
        platform_admin: true
      )
      visible = described_class.visible_to(user)

      expect(visible).to include(shared_contact, chs_contact, md_contact)
    end

    it 'returns shared and company entries for company user' do
      user = create(
        :user,
        account: account,
        company: chs_company,
        role: User::ADMIN_ROLE
      )
      visible = described_class.visible_to(user)

      expect(visible).to include(shared_contact, chs_contact)
      expect(visible).not_to include(md_contact)
    end
  end
end
