# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanySmtpSettings do
  let(:company) { Company.new }

  describe '.resolve' do
    it 'returns nil when company is nil' do
      expect(described_class.resolve(nil)).to be_nil
    end

    it 'returns nil when smtp_enabled is false' do
      company.smtp_enabled = false
      expect(described_class.resolve(company)).to be_nil
    end

    it 'returns nil when smtp_enabled is true but smtp_address is blank' do
      company.smtp_enabled = true
      company.smtp_address = ''
      company.smtp_port = 587
      expect(described_class.resolve(company)).to be_nil
    end

    it 'returns nil when smtp_enabled is true but smtp_port is blank' do
      company.smtp_enabled = true
      company.smtp_address = 'smtp.example.com'
      company.smtp_port = nil
      expect(described_class.resolve(company)).to be_nil
    end

    it 'returns settings hash when enabled' do
      company.smtp_enabled = true
      company.smtp_address = 'smtp.example.com'
      company.smtp_port = 587
      company.smtp_domain = 'example.com'
      company.smtp_user_name = 'user'
      company.smtp_password = 'password'
      company.smtp_authentication = 'login'
      company.smtp_enable_starttls_auto = true

      settings = described_class.resolve(company)
      expect(settings).to be_a(Hash)
      expect(settings[:address]).to eq('smtp.example.com')
      expect(settings[:port]).to eq(587)
      expect(settings[:domain]).to eq('example.com')
      expect(settings[:user_name]).to eq('user')
      expect(settings[:password]).to eq('password')
      expect(settings[:authentication]).to eq('login')
      expect(settings[:enable_starttls_auto]).to be true
      expect(settings[:open_timeout]).to eq(ActionMailerConfigsInterceptor::OPEN_TIMEOUT)
      expect(settings[:read_timeout]).to eq(ActionMailerConfigsInterceptor::READ_TIMEOUT)
    end

    it 'omits blank optional fields' do
      company.smtp_enabled = true
      company.smtp_address = 'smtp.example.com'
      company.smtp_port = 587
      company.smtp_password = nil

      settings = described_class.resolve(company)
      expect(settings).to be_a(Hash)
      expect(settings[:address]).to eq('smtp.example.com')
      expect(settings[:port]).to eq(587)
      expect(settings.key?(:password)).to be false
      expect(settings.key?(:authentication)).to be false
      expect(settings.key?(:domain)).to be false
      expect(settings.key?(:user_name)).to be false
    end
  end

  describe '.from_address' do
    it 'returns nil when company is nil' do
      expect(described_class.from_address(nil)).to be_nil
    end

    it 'returns nil when smtp_enabled is false' do
      company.smtp_enabled = false
      company.smtp_from_email = 'no-reply@example.com'
      expect(described_class.from_address(company)).to be_nil
    end

    it 'returns nil when smtp_from_email is blank' do
      company.smtp_enabled = true
      company.smtp_from_email = nil
      expect(described_class.from_address(company)).to be_nil
    end

    it 'formats from address with company name when from_name is blank' do
      company.smtp_enabled = true
      company.name = 'Acme Corp'
      company.smtp_from_email = 'no-reply@example.com'
      company.smtp_from_name = nil
      expect(described_class.from_address(company)).to eq('"Acme Corp" <no-reply@example.com>')
    end

    it 'formats from address with from_name when present' do
      company.smtp_enabled = true
      company.name = 'Acme Corp'
      company.smtp_from_email = 'no-reply@example.com'
      company.smtp_from_name = 'Acme Support'
      expect(described_class.from_address(company)).to eq('"Acme Support" <no-reply@example.com>')
    end
  end
end
