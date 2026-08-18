# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  let(:company) { Company.new(id: 100, name: 'Acme Corp') }
  let(:record_class) { Struct.new(:name) }
  let(:fake_record_class) do
    Class.new do
      attr_accessor :id, :class, :company_id, :company, :submission, :template

      def initialize(attrs = {})
        attrs.each { |k, v| send("#{k}=", v) }
      end
    end
  end

  describe '#assign_message_metadata' do
    let(:mailer) { described_class.new }

    it 'includes record_type and record_id without company_id if no safe context exists' do
      record = fake_record_class.new(id: 99, class: record_class.new('FakeRecord'))
      mailer.assign_message_metadata('fake_tag', record)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata).to include(
        'tag' => 'fake_tag',
        'record_id' => 99,
        'record_type' => 'FakeRecord'
      )
      expect(metadata).not_to have_key('company_id')
    end

    it 'includes company_id when record has company_id directly' do
      user = User.new(id: 1, company_id: company.id)
      mailer.assign_message_metadata('user_invitation', user)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['company_id']).to eq(company.id)
      expect(metadata['record_type']).to eq('User')
    end

    it 'includes company_id when record has company association directly' do
      record = fake_record_class.new(
        id: 42, class: record_class.new('CustomRecord'), company_id: nil, company: company
      )
      mailer.assign_message_metadata('custom_tag', record)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['company_id']).to eq(company.id)
    end

    it 'includes company_id through submission if applicable' do
      submission = Submission.new(id: 10, company_id: company.id)
      record = fake_record_class.new(
        id: 55, class: record_class.new('Submitter'), company_id: nil, submission: submission
      )

      mailer.assign_message_metadata('submitter_invitation', record)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['company_id']).to eq(company.id)
    end

    it 'includes company_id using a real Submission model directly' do
      submission = Submission.new(id: 10, company_id: company.id)
      mailer.assign_message_metadata('submission_tag', submission)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['company_id']).to eq(company.id)
      expect(metadata['record_type']).to eq('Submission')
    end

    it 'includes company_id using a real Submitter model associated with a submission' do
      submission = Submission.new(id: 10, company_id: company.id)
      submitter = Submitter.new(id: 55, submission: submission)

      # Even if submitter.company_id is blank, the helper checks submitter.submission.company_id
      submitter.company_id = nil

      mailer.assign_message_metadata('submitter_invitation', submitter)

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['company_id']).to eq(company.id)
      expect(metadata['record_type']).to eq('Submitter')
    end

    it 'does not raise error and omits company_id if standard error occurs in helper' do
      record = fake_record_class.new(id: 11, class: record_class.new('BrokenRecord'))
      allow(record).to receive(:company_id).and_raise(StandardError, 'database error')

      expect do
        mailer.assign_message_metadata('broken_tag', record)
      end.not_to raise_error

      metadata = mailer.instance_variable_get(:@message_metadata)
      expect(metadata['record_id']).to eq(11)
      expect(metadata).not_to have_key('company_id')
    end
  end
end
