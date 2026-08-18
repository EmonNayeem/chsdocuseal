# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionMailerConfigsInterceptor do
  let(:company) { Company.new(id: 100, name: 'Test Company') }
  let(:account) { Account.new(id: 200, name: 'Test Account') }
  let(:message) { Mail.new(to: 'test@example.com', from: 'original@example.com', body: 'hello') }

  before do
    allow(company).to receive(:account).and_return(account)
    allow(Company).to receive(:find_by).with(id: company.id).and_return(company)
    allow(Company).to receive(:find_by).with(id: 999_999).and_return(nil)

    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Docuseal).to receive_messages(demo?: false, multitenant?: false)
    allow(Rails.application.config.action_mailer).to receive_messages(delivery_method: nil)
  end

  describe '.delivering_email' do
    context 'when company SMTP is configured and valid' do
      before do
        message.instance_variable_set(:@message_metadata, { 'company_id' => company.id })

        company.assign_attributes(
          smtp_enabled: true,
          smtp_address: 'smtp.company.com',
          smtp_port: 587,
          smtp_user_name: 'user',
          smtp_password: 'pwd',
          smtp_from_email: 'company@example.com'
        )
      end

      it 'uses company SMTP and sets the from address' do
        described_class.delivering_email(message)

        expect(message.delivery_method.class).to eq(Mail::SMTP)
        expect(message.delivery_method.settings[:address]).to eq('smtp.company.com')
        expect(message.delivery_method.settings[:user_name]).to eq('user')
        expect(message.from).to contain_exactly('company@example.com')
      end
    end

    context 'when company SMTP is missing company_id' do
      it 'does not use company SMTP and falls back' do
        message.instance_variable_set(:@message_metadata, { 'other_id' => 1 })

        allow(CompanySmtpSettings).to receive(:resolve)

        # Will fallback to test or ENV or global config
        described_class.delivering_email(message)

        expect(CompanySmtpSettings).not_to have_received(:resolve)
        expect(message.delivery_method.settings[:address]).not_to eq('smtp.company.com')
      end
    end

    context 'when company SMTP is disabled for the company' do
      before do
        message.instance_variable_set(:@message_metadata, { 'company_id' => company.id })

        company.assign_attributes(
          smtp_enabled: false,
          smtp_address: 'smtp.company.com',
          smtp_port: 587
        )
      end

      it 'falls back to existing behavior' do
        expect(CompanySmtpSettings.resolve(company)).to be_nil

        described_class.delivering_email(message)
        expect(message.delivery_method.settings[:address]).not_to eq('smtp.company.com')
      end
    end

    context 'when company_id points to a missing company' do
      it 'falls back to existing behavior safely' do
        message.instance_variable_set(:@message_metadata, { 'company_id' => 999_999 })

        expect do
          described_class.delivering_email(message)
        end.not_to raise_error
      end
    end

    context 'when company SMTP throws an exception' do
      before do
        message.instance_variable_set(:@message_metadata, { 'company_id' => company.id })
        allow(CompanySmtpSettings).to receive(:resolve).and_raise(StandardError, 'Oops')
      end

      it 'rescues safely and falls back' do
        expect do
          described_class.delivering_email(message)
        end.not_to raise_error
      end
    end

    context 'when existing account-level SMTP behavior is present and no company SMTP exists' do
      let(:encrypted_config) do
        EncryptedConfig.create!(
          account: company.account,
          key: EncryptedConfig::EMAIL_SMTP_KEY,
          value: {
            'host' => 'smtp.account.com',
            'port' => 2525,
            'from_email' => 'account@example.com'
          }
        )
      end

      before do
        encrypted_config
        # No delivery method configured via rails to avoid early return
        allow(Rails.application.config.action_mailer).to receive_messages(delivery_method: nil)
      end

      it 'uses account-level SMTP' do
        message.instance_variable_set(:@message_metadata, {})

        described_class.delivering_email(message)

        expect(message.delivery_method.class).to eq(Mail::SMTP)
        expect(message.delivery_method.settings[:address]).to eq('smtp.account.com')
        expect(message.delivery_method.settings[:port]).to eq(2525)
        expect(message.from).to contain_exactly('account@example.com')
      end
    end
  end
end
