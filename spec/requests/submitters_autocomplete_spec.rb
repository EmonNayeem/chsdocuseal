# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SubmittersAutocomplete', type: :request do
  let(:account) { create(:account) }
  let(:chs_company) { account.companies.find_by!(code: 'CHS') }
  let(:md_company) { account.companies.find_by!(code: 'MD') }

  before do
    create(
      :recipient_contact,
      account: account,
      company: chs_company,
      email: 'contact.chs@example.com',
      name: 'Contact CHS'
    )
    create(
      :recipient_contact,
      account: account,
      company: md_company,
      email: 'contact.md@example.com',
      name: 'Contact MD'
    )
    create(
      :recipient_contact,
      account: account,
      company: nil,
      email: 'contact.shared@example.com',
      name: 'Contact Shared'
    )
  end

  describe 'GET /submitters_autocomplete' do
    context 'when logged in as CHS Editor (no departments)' do
      let(:user) { create(:user, account: account, company: chs_company, role: User::EDITOR_ROLE) }

      before do
        login_as(user, scope: :user)
      end

      it 'returns empty array safely for blank query' do
        get submitters_autocomplete_index_path(field: 'email')

        expect(response).to be_successful
        expect(response.parsed_body).to eq([])
      end

      it 'includes CHS, Shared, excludes MD' do
        get submitters_autocomplete_index_path(field: 'email', q: 'contact')
        emails = response.parsed_body.pluck('email')

        expect(emails).to include('contact.chs@example.com', 'contact.shared@example.com')
        expect(emails).not_to include('contact.md@example.com')
      end

      it 'excludes history for Editor with no departments' do
        template = create(:template, account: account, author: user)
        submission = create(:submission, :with_submitters, template: template, created_by_user: user)
        submission.submitters.first.update!(email: 'historical@example.com')

        get submitters_autocomplete_index_path(field: 'email', q: 'historical')
        emails = response.parsed_body.pluck('email')

        expect(emails).not_to include('historical@example.com')
      end

      it 'excludes cross-account contacts and history' do
        other_account = create(:account)
        other_chs = other_account.companies.find_by!(code: 'CHS')
        other_user = create(:user, account: other_account, company: other_chs, role: User::EDITOR_ROLE)

        create(:recipient_contact, account: other_account, company: other_chs, email: 'other.contact@example.com')

        template = create(:template, account: other_account, author: other_user)
        submission = create(:submission, :with_submitters, template: template, created_by_user: other_user)
        submission.submitters.first.update!(email: 'other.hist@example.com')

        get submitters_autocomplete_index_path(field: 'email', q: 'other')
        emails = response.parsed_body.pluck('email')

        expect(emails).not_to include('other.contact@example.com', 'other.hist@example.com')
      end
    end

    context 'when logged in as CHS Admin (authorized for history)' do
      let(:chs_admin) do
        create(
          :user,
          account: account,
          company: chs_company,
          role: User::ADMIN_ROLE
        )
      end

      before do
        login_as(chs_admin, scope: :user)
      end

      it 'falls back to historical submitters' do
        template = create(:template, account: account, author: chs_admin)
        submission = create(:submission, :with_submitters, template: template, created_by_user: chs_admin)
        submission.submitters.first.update!(email: 'historical@example.com', name: 'Historical')

        get submitters_autocomplete_index_path(field: 'email', q: 'historical')
        emails = response.parsed_body.pluck('email')

        expect(emails).to include('historical@example.com')
      end

      it 'deduplicates directory matches over history' do
        template = create(:template, account: account, author: chs_admin)
        submission = create(:submission, :with_submitters, template: template, created_by_user: chs_admin)
        submission.submitters.first.update!(email: 'contact.chs@example.com', name: 'Old Name', phone: 'OLD')

        get submitters_autocomplete_index_path(field: 'email', q: 'contact')

        matches = response.parsed_body.select { |j| j['email'] == 'contact.chs@example.com' }
        expect(matches.size).to eq(1)
        expect(matches.first['name']).to eq('Contact CHS') # Directory name wins
        expect(matches.first['source']).to eq('directory')
      end
    end

    context 'when logged in as MD user' do
      let(:user) { create(:user, account: account, company: md_company, role: User::EDITOR_ROLE) }

      before do
        login_as(user, scope: :user)
      end

      it 'includes MD, Shared, excludes CHS' do
        get submitters_autocomplete_index_path(field: 'email', q: 'contact')
        emails = response.parsed_body.pluck('email')

        expect(emails).to include('contact.md@example.com', 'contact.shared@example.com')
        expect(emails).not_to include('contact.chs@example.com')
      end
    end

    context 'when logged in as Platform Admin' do
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

      it 'includes all three directory contacts' do
        get submitters_autocomplete_index_path(field: 'email', q: 'contact')
        emails = response.parsed_body.pluck('email')

        expect(emails).to include('contact.chs@example.com', 'contact.md@example.com', 'contact.shared@example.com')
      end
    end
  end
end
