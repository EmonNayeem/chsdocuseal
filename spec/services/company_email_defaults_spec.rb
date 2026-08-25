# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanyEmailDefaults do
  describe '.invitation_subject' do
    it 'returns CHS default subject for CHS' do
      expect(described_class.invitation_subject('CHS')).to eq('Churchfield Home Services document request')
    end

    it 'returns MD default subject for MD' do
      expect(described_class.invitation_subject('MD')).to eq('Materials Direct document request')
    end

    it 'returns SL default subject for SL' do
      expect(described_class.invitation_subject('SL')).to eq('Smart Lotto document request')
    end

    it 'returns ESS default subject for ESS' do
      expect(described_class.invitation_subject('ESS')).to eq('Efficient Software Solutions document request')
    end

    it 'returns CHS default subject for unknown company' do
      expect(described_class.invitation_subject('UNKNOWN')).to eq('Churchfield Home Services document request')
    end

    it 'handles nil company' do
      expect(described_class.invitation_subject(nil)).to eq('Churchfield Home Services document request')
    end

    it 'handles lowercase company string' do
      expect(described_class.invitation_subject('md')).to eq('Materials Direct document request')
    end

    it 'handles company object' do
      company = instance_double(Company, code: 'ESS')
      expect(described_class.invitation_subject(company)).to eq('Efficient Software Solutions document request')
    end
  end

  describe '.invitation_body' do
    it 'returns CHS default body for CHS' do
      body = described_class.invitation_body('CHS')
      expect(body).to include('Churchfield Home Services has sent you a document to review and complete.')
      expect(body).to include('Churchfield Home Services')
    end

    it 'returns MD default body for MD' do
      body = described_class.invitation_body('MD')
      expect(body).to include('Materials Direct has sent you a document to review and complete.')
      expect(body).to include('Materials Direct')
    end

    it 'returns SL default body for SL' do
      body = described_class.invitation_body('SL')
      expect(body).to include('Smart Lotto has sent you a document to review and complete.')
      expect(body).to include('Smart Lotto')
    end

    it 'returns ESS default body for ESS' do
      body = described_class.invitation_body('ESS')
      expect(body).to include('Efficient Software Solutions has sent you a document to review and complete.')
      expect(body).to include('Efficient Software Solutions')
    end

    it 'returns CHS default body for unknown company' do
      body = described_class.invitation_body('UNKNOWN')
      expect(body).to include('Churchfield Home Services has sent you a document to review and complete.')
    end
  end

  describe '.company_for_submitter' do
    let(:md_company) { Company.new(code: 'MD') }
    let(:sl_company) { Company.new(code: 'SL') }
    let(:ess_company) { Company.new(code: 'ESS') }
    let(:chs_company) { Company.new(code: 'CHS') }

    let(:template) { build(:template, company: md_company) }
    let(:submission) { build(:submission, template: template, company: nil) }
    let(:submitter) { build(:submitter, submission: submission, company: nil) }

    before do
      allow(Company).to receive(:find_by).with(code: 'CHS').and_return(chs_company)
    end

    it 'resolves company from template if present' do
      expect(described_class.company_for_submitter(submitter)).to eq(md_company)
    end

    it 'resolves company from submission if template company is blank' do
      template.company = nil
      submission.company = sl_company
      expect(described_class.company_for_submitter(submitter)).to eq(sl_company)
    end

    it 'resolves company from submitter if others are blank' do
      template.company = nil
      submission.company = nil
      submitter.company = ess_company
      expect(described_class.company_for_submitter(submitter)).to eq(ess_company)
    end

    it 'falls back to CHS if all are blank' do
      template.company = nil
      submission.company = nil
      submitter.company = nil
      expect(described_class.company_for_submitter(submitter)).to eq(chs_company)
    end
  end
end
