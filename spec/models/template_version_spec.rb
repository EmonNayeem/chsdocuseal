# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateVersion, type: :model do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:author) { create(:user, account:, company:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, company:, author:) }

  describe 'associations and attachments' do
    it 'has documents and dynamic_attachments associations' do
      version = described_class.create!(
        template:,
        author:,
        account:,
        company:,
        data: { 'name' => template.name, 'schema' => [] },
        sha1: 'test_sha1'
      )
      expect(version).to respond_to(:documents)
      expect(version).to respond_to(:documents_attachments)
      expect(version).to respond_to(:dynamic_attachments)
      expect(version).to respond_to(:dynamic_attachments_attachments)
    end
  end

  describe 'tenancy' do
    it 'inherits company from template on create and does not fall back to arbitrary MD company' do
      version = described_class.create!(
        template:,
        author:,
        data: { 'name' => template.name },
        sha1: 'test_sha1'
      )

      expect(version.company_id).to eq(company.id)
      expect(version.account_id).to eq(account.id)
    end

    it 'validates that company matches template company' do
      version = described_class.new(
        template:,
        author:,
        account:,
        company: other_company,
        data: { 'name' => template.name },
        sha1: 'test_sha1'
      )

      expect(version).not_to be_valid
      expect(version.errors[:company_id]).to include('must match template company')
    end

    it 'validates that account matches template account' do
      other_account = create(:account)
      version = described_class.new(
        template:,
        author:,
        account: other_account,
        company:,
        data: { 'name' => template.name },
        sha1: 'test_sha1'
      )

      expect(version).not_to be_valid
      expect(version.errors[:account_id]).to include('must match template account')
    end
  end

  describe '#version_number' do
    it 'computes 1-based chronological version number' do
      v1 = described_class.create!(
        template:,
        author:,
        data: { 'name' => 'V1' },
        sha1: 'sha1'
      )
      v2 = described_class.create!(
        template:,
        author:,
        data: { 'name' => 'V2' },
        sha1: 'sha2'
      )

      expect(v1.version_number).to eq(1)
      expect(v2.version_number).to eq(2)
    end
  end
end
