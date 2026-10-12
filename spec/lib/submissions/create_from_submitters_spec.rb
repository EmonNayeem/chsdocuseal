# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::CreateFromSubmitters do
  let(:account) { create(:account) }
  let(:chs_company) { account.companies.find_by!(code: 'CHS') }
  let(:md_company) { account.companies.find_by!(code: 'MD') }
  let(:user) { create(:user, account: account, company: chs_company) }
  let(:template) { create(:template, account: account, author: user) }

  before do
    template.update!(
      submitters: [{ 'uuid' => 'p1', 'name' => 'Party 1' }, { 'uuid' => 'p2', 'name' => 'Party 2' }],
      fields: [
        { 'uuid' => 'f1', 'name' => 'f1', 'type' => 'text', 'submitter_uuid' => 'p1',
          'recipient_mapping' => 'job_title' },
        { 'uuid' => 'f2', 'name' => 'f2', 'type' => 'text', 'submitter_uuid' => 'p1',
          'recipient_mapping' => 'department' },
        { 'uuid' => 'f3', 'name' => 'f3', 'type' => 'text', 'submitter_uuid' => 'p1', 'recipient_mapping' => 'name' },
        { 'uuid' => 'f4', 'name' => 'f4', 'type' => 'select', 'submitter_uuid' => 'p1',
          'recipient_mapping' => 'department', 'options' => [{ 'value' => 'IT' }, { 'value' => 'HR' }] },
        { 'uuid' => 'f5', 'name' => 'f5', 'type' => 'text', 'submitter_uuid' => 'p2',
          'recipient_mapping' => 'job_title' }
      ]
    )
  end

  describe 'recipient mapping and metadata snapshot' do
    let(:contact) do
      create(:recipient_contact, account: account, company: chs_company, email: 'contact@example.com',
                                 name: 'Directory Name', phone: '+123456', job_title: 'Engineer', department: 'IT')
    end

    let(:shared_contact) do
      create(:recipient_contact, account: account, company: nil, email: 'shared@example.com',
                                 name: 'Shared Name', phone: '+222222', job_title: 'Manager', department: 'HR')
    end

    let(:md_contact) do
      create(:recipient_contact, account: account, company: md_company, email: 'md@example.com',
                                 name: 'MD Name', phone: '+333333', job_title: 'MD Title', department: 'MD Dept')
    end

    it 'A. visible directory contact creates metadata snapshot' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.metadata['recipient']).to eq({
                                                      'contact_id' => contact.id,
                                                      'job_title' => 'Engineer',
                                                      'department' => 'IT'
                                                    })
    end

    it 'B. contact name/phone are fallback when submitted values blank' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com', name: '', phone: '' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.name).to eq('Directory Name')
      expect(submitter.phone).to eq('+123456')
    end

    it 'C. explicit submitted name/phone win' do
      contact
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: [
          { submitters: [{ role: 'Party 1', email: 'contact@example.com', name: 'Explicit', phone: '+9999' }] }
        ].map(&:with_indifferent_access)
      )
      submitter = submissions.first.submitters.first

      expect(submitter.name).to eq('Explicit')
      expect(submitter.phone).to eq('+9999')
    end

    it 'D. mapped text field blank -> job_title applied' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.values['f1']).to eq('Engineer')
    end

    it 'E. explicit mapped text value -> explicit value wins' do
      contact
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: [
          { submitters: [{ role: 'Party 1', email: 'contact@example.com', values: { 'f1' => 'Custom' } }] }
        ].map(&:with_indifferent_access)
      )
      submitter = submissions.first.submitters.first

      expect(submitter.values['f1']).to eq('Custom')
    end

    it 'F. mapped department -> applied' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.values['f2']).to eq('IT')
    end

    it 'G. mapped select valid option -> applied' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.values['f4']).to eq('IT')
    end

    it 'H. mapped select invalid option -> NOT applied' do
      contact.update!(department: 'Invalid')
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.values['f4']).to be_nil
    end

    it 'I. Party A mapping does not populate Party B' do
      contact
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: [
          { submitters: [
            { role: 'Party 1', email: 'contact@example.com' },
            { role: 'Party 2', email: 'other@example.com' }
          ] }
        ].map(&:with_indifferent_access)
      )
      party2 = submissions.first.submitters.find { |s| s.uuid == 'p2' }
      expect(party2.values['f5']).to be_nil
    end

    it 'J. CHS user manually entering MD recipient email -> no MD snapshot, no MD mapped metadata' do
      md_contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'md@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.metadata['recipient']).to be_nil
      expect(submitter.values['f1']).to be_nil
    end

    it 'K. Shared contact works' do
      shared_contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'shared@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.metadata['recipient']).to be_present
      expect(submitter.values['f1']).to eq('Manager')
    end

    it 'L. cross-account contact does not resolve' do
      other_account = create(:account)
      create(:recipient_contact, account: other_account, company: nil, email: 'cross@example.com', job_title: 'Cross')

      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'cross@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      expect(submitter.metadata['recipient']).to be_nil
      expect(submitter.values['f1']).to be_nil
    end

    it 'M. directory edited AFTER creation -> existing Submitter metadata remains old snapshot' do
      contact
      attrs = [
        {
          submitters: [
            { role: 'Party 1', email: 'contact@example.com' }
          ]
        }
      ].map(&:with_indifferent_access)
      submissions = described_class.call(
        template: template, user: user, source: 'api', submitters_order: 'preserved',
        submissions_attrs: attrs
      )
      submitter = submissions.first.submitters.first

      contact.update!(job_title: 'Director')

      expect(submitter.reload.metadata.dig('recipient', 'job_title')).to eq('Engineer')
      expect(submitter.values['f1']).to eq('Engineer')
    end
  end
end
