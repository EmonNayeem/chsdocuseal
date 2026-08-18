# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  brand_from_email_name     :string
#  brand_icon_key            :string
#  brand_logo_key            :string
#  brand_name                :string
#  brand_primary_color       :string
#  branding_enabled          :boolean          default(FALSE), not null
#  code                      :string           not null
#  name                      :string           not null
#  smtp_address              :string
#  smtp_authentication       :string
#  smtp_domain               :string
#  smtp_enable_starttls_auto :boolean          default(FALSE), not null
#  smtp_enabled              :boolean          default(FALSE), not null
#  smtp_from_email           :string
#  smtp_from_name            :string
#  smtp_password             :text
#  smtp_port                 :integer
#  smtp_user_name            :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#
# Indexes
#
#  index_companies_on_account_id           (account_id)
#  index_companies_on_account_id_and_code  (account_id,code) UNIQUE
#  index_companies_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'SMTP settings validations' do
    let(:account) { create(:account) }
    let(:company) { described_class.new(account: account, name: 'Test', code: 'test') }

    context 'when smtp_enabled is false' do
      before { company.smtp_enabled = false }

      it 'is valid without SMTP fields' do
        expect(company).to be_valid
      end
    end

    context 'when smtp_enabled is true' do
      before do
        company.smtp_enabled = true
        company.smtp_address = 'smtp.example.com'
        company.smtp_port = 587
        company.smtp_from_email = 'no-reply@example.com'
      end

      it 'is valid with all required SMTP fields' do
        expect(company).to be_valid
      end

      it 'is invalid without smtp_address' do
        company.smtp_address = nil
        expect(company).not_to be_valid
        expect(company.errors[:smtp_address]).to include("can't be blank")
      end

      it 'is invalid without smtp_port' do
        company.smtp_port = nil
        expect(company).not_to be_valid
        expect(company.errors[:smtp_port]).to include("can't be blank")
      end

      it 'is invalid with non-integer smtp_port' do
        company.smtp_port = 'abc'
        expect(company).not_to be_valid
        expect(company.errors[:smtp_port]).to include('is not a number')
      end

      it 'is invalid without smtp_from_email' do
        company.smtp_from_email = nil
        expect(company).not_to be_valid
        expect(company.errors[:smtp_from_email]).to include("can't be blank")
      end

      it 'is invalid with malformed smtp_from_email' do
        company.smtp_from_email = 'invalid-email'
        expect(company).not_to be_valid
        expect(company.errors[:smtp_from_email]).to include('is invalid')
      end
    end
  end

  describe '#smtp_password' do
    let(:account) { create(:account) }
    let(:company) do
      described_class.create!(
        account: account, name: 'Test', code: 'test', smtp_password: 'supersecretpassword'
      )
    end

    it 'encrypts the password in the database' do
      # NOTE: checking the raw database value depends on how ActiveRecord encrypts
      # but generally we just need to know it's not plain text.
      # ActiveRecord encryption transparently decrypts it when accessed.
      expect(company.smtp_password).to eq('supersecretpassword')

      # We can check that the raw value isn't the password
      sql = "SELECT smtp_password FROM companies WHERE id = #{company.id}"
      raw_password = described_class.connection.select_value(sql)
      expect(raw_password).not_to include('supersecretpassword')
    end
  end

  describe 'branding validations' do
    let(:account) { create(:account) }
    let(:company) { described_class.new(account: account, name: 'Test', code: 'test') }

    context 'when branding_enabled is false' do
      before { company.branding_enabled = false }

      it 'allows blank brand fields' do
        company.brand_name = nil
        expect(company).to be_valid
      end
    end

    context 'when branding_enabled is true' do
      before { company.branding_enabled = true }

      it 'requires brand_name' do
        company.brand_name = nil
        expect(company).not_to be_valid
        expect(company.errors[:brand_name]).to include("can't be blank")
      end

      it 'is valid with brand_name' do
        company.brand_name = 'Acme Brand'
        expect(company).to be_valid
      end
    end

    describe 'brand_primary_color' do
      let(:account) { create(:account) }
      let(:company) { described_class.new(account: account, name: 'Test', code: 'test') }

      it 'accepts valid hex colors' do
        company.brand_primary_color = '#FFFFFF'
        expect(company).to be_valid

        company.brand_primary_color = '#000'
        expect(company).to be_valid

        company.brand_primary_color = '#AABBCC'
        expect(company).to be_valid
      end

      it 'rejects invalid colors' do
        company.brand_primary_color = 'FFFFFF' # missing #
        expect(company).not_to be_valid

        company.brand_primary_color = '#ZZZZZZ' # invalid hex
        expect(company).not_to be_valid

        company.brand_primary_color = '#1234' # wrong length
        expect(company).not_to be_valid
      end
    end
  end

  describe '#branded_name' do
    let(:account) { create(:account) }
    let(:company) { described_class.new(account: account, name: 'Original Name', code: 'test') }

    it 'falls back to company name when branding disabled' do
      company.branding_enabled = false
      company.brand_name = 'Custom Brand'
      expect(company.branded_name).to eq('Original Name')
    end

    it 'uses brand_name when enabled and present' do
      company.branding_enabled = true
      company.brand_name = 'Custom Brand'
      expect(company.branded_name).to eq('Custom Brand')
    end

    it 'falls back to company name if enabled but brand_name is blank' do
      company.branding_enabled = true
      company.brand_name = '  '
      expect(company.branded_name).to eq('Original Name')
    end
  end
end
