# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityEvents', type: :request do
  let(:account) { create(:account) }
  let(:chs_company) { account.companies.find_by!(code: 'CHS') }
  let(:md_company) { account.companies.find_by!(code: 'MD') }

  let(:platform_admin) do
    create(
      :user, account:, company: chs_company, role: User::ADMIN_ROLE,
             platform_admin: true, first_name: 'Platform', last_name: 'Admin',
             email: 'platform.admin@example.com'
    )
  end

  let(:chs_admin) do
    create(
      :user, account:, company: chs_company, role: User::ADMIN_ROLE,
             platform_admin: false, first_name: 'CHS', last_name: 'Admin',
             email: 'chs.admin@example.com'
    )
  end

  let(:md_admin) do
    create(
      :user, account:, company: md_company, role: User::ADMIN_ROLE,
             platform_admin: false, first_name: 'MD', last_name: 'Admin',
             email: 'md.admin@example.com'
    )
  end

  let(:editor) do
    create(:user, account:, company: chs_company, role: User::EDITOR_ROLE, platform_admin: false)
  end

  let(:viewer) do
    create(:user, account:, company: chs_company, role: User::VIEWER_ROLE, platform_admin: false)
  end

  before do
    ActivityEvents.record!(
      actor: chs_admin,
      action: 'recipient_contact.created',
      subject_label: 'CHS Contact <chs@example.com>',
      subject_type: 'RecipientContact',
      subject_id: 101,
      account_id: account.id,
      company_id: chs_company.id,
      visibility_scope: 'company',
      occurred_at: 2.hours.ago
    )

    ActivityEvents.record!(
      actor: md_admin,
      action: 'template.created',
      subject_label: 'MD Policy Template',
      subject_type: 'Template',
      subject_id: 202,
      account_id: account.id,
      company_id: md_company.id,
      visibility_scope: 'company',
      occurred_at: 1.hour.ago
    )

    ActivityEvents.record!(
      actor: platform_admin,
      action: 'recipient_contact.created',
      subject_label: 'Shared Vendor <vendor@example.com>',
      subject_type: 'RecipientContact',
      subject_id: 303,
      account_id: account.id,
      company_id: nil,
      visibility_scope: 'account',
      occurred_at: 30.minutes.ago
    )
  end

  describe 'Authorization' do
    it 'allows platform admin access' do
      login_as(platform_admin, scope: :user)
      get settings_activity_events_path
      expect(response).to be_successful
      expect(response.body).to include('Activity Log')
    end

    it 'paginates activity events and resolves pagination.events translation under en-US' do
      account.update!(locale: 'en-US')
      login_as(platform_admin, scope: :user)

      30.times do |i|
        label =
          if i.zero?
            'Oldest Pagination Record'
          elsif i == 29
            'Newest Pagination Record'
          else
            "Pagination Form #{i + 1}"
          end

        ActivityEvent.create!(
          account_id: account.id,
          company_id: chs_company.id,
          actor_user_id: platform_admin.id,
          action: 'template.created',
          subject_type: 'Template',
          subject_id: 1000 + i,
          subject_label: label,
          actor_name: 'Platform Admin',
          actor_email: platform_admin.email,
          visibility_scope: 'company',
          occurred_at: (35 - i).minutes.ago
        )
      end

      total_events = ActivityEvent.where(account_id: account.id).count

      get settings_activity_events_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1-25 of #{total_events} events")
      expect(response.body).to include('Newest Pagination Record')
      expect(response.body).not_to include('Oldest Pagination Record')

      get settings_activity_events_path, params: { page: 2 }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("26-#{total_events} of #{total_events} events")
      expect(response.body).to include('Oldest Pagination Record')
      expect(response.body).not_to include('Newest Pagination Record')
    end

    it 'allows company admin access' do
      login_as(chs_admin, scope: :user)
      get settings_activity_events_path
      expect(response).to be_successful
      expect(response.body).to include('Activity Log')
    end

    it 'denies editor access' do
      login_as(editor, scope: :user)
      get settings_activity_events_path
      expect(response).to redirect_to(root_path)
    end

    it 'denies viewer access' do
      login_as(viewer, scope: :user)
      get settings_activity_events_path
      expect(response).to redirect_to(root_path)
    end

    it 'redirects unauthenticated users' do
      get settings_activity_events_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'Multi-tenancy and Visibility' do
    let(:other_account) { create(:account) }
    let(:other_company) { other_account.companies.first }
    let(:other_platform_admin) do
      create(:user, account: other_account, company: other_company, role: User::ADMIN_ROLE, platform_admin: true)
    end

    before do
      ActivityEvents.record!(
        actor: other_platform_admin,
        action: 'template.created',
        subject_label: 'External Account Form',
        subject_type: 'Template',
        subject_id: 404,
        account_id: other_account.id,
        company_id: other_company.id,
        visibility_scope: 'company',
        occurred_at: 10.minutes.ago
      )
    end

    it 'allows platform admin to see all account events across companies' do
      login_as(platform_admin, scope: :user)
      get settings_activity_events_path

      expect(response.body).to include('CHS Contact')
      expect(response.body).to include('MD Policy Template')
      expect(response.body).to include('Shared Vendor')
      expect(response.body).not_to include('External Account Form')
    end

    it 'restricts CHS company admin to own company and account-scoped events' do
      login_as(chs_admin, scope: :user)
      get settings_activity_events_path

      expect(response.body).to include('CHS Contact')
      expect(response.body).to include('Shared Vendor')
      expect(response.body).not_to include('MD Policy Template')
      expect(response.body).not_to include('External Account Form')
    end

    it 'restricts MD company admin to own company and account-scoped events' do
      login_as(md_admin, scope: :user)
      get settings_activity_events_path

      expect(response.body).to include('MD Policy Template')
      expect(response.body).to include('Shared Vendor')
      expect(response.body).not_to include('CHS Contact')
      expect(response.body).not_to include('External Account Form')
    end

    it 'prevents other account admin from seeing account A events' do
      login_as(other_platform_admin, scope: :user)
      get settings_activity_events_path

      expect(response.body).to include('External Account Form')
      expect(response.body).not_to include('CHS Contact')
      expect(response.body).not_to include('MD Policy Template')
      expect(response.body).not_to include('Shared Vendor')
    end
  end

  describe 'Filtering' do
    before do
      login_as(platform_admin, scope: :user)
    end

    it 'filters by action' do
      get settings_activity_events_path, params: { action_name: 'template.created' }

      expect(response.body).to include('MD Policy Template')
      expect(response.body).not_to include('CHS Contact')
      expect(response.body).not_to include('Shared Vendor')
    end

    it 'filters by actor' do
      get settings_activity_events_path, params: { actor_id: chs_admin.id }

      expect(response.body).to include('CHS Contact')
      expect(response.body).not_to include('MD Policy Template')
      expect(response.body).not_to include('Shared Vendor')
    end

    it 'filters by date range' do
      get settings_activity_events_path, params: {
        from_date: Date.current.to_s,
        to_date: Date.current.to_s
      }

      expect(response.body).to include('CHS Contact')
      expect(response.body).to include('MD Policy Template')
    end

    it 'allows platform admin to filter by company' do
      get settings_activity_events_path, params: { company_id: md_company.id }

      expect(response.body).to include('MD Policy Template')
      expect(response.body).not_to include('CHS Contact')
    end

    it 'prevents company admin from seeing other companies via company_id param' do
      login_as(chs_admin, scope: :user)
      get settings_activity_events_path, params: { company_id: md_company.id }

      # Should NOT see MD events even if params[:company_id] is MD
      expect(response.body).not_to include('MD Policy Template')
      expect(response.body).to include('CHS Contact')
    end

    it 'restricts Company Admin actor dropdown to actors from visible events only' do
      login_as(chs_admin, scope: :user)
      get settings_activity_events_path

      expect(response.body).to include('CHS Admin')
      expect(response.body).to include('Platform Admin')
      expect(response.body).not_to include('MD Admin')
      expect(response.body).not_to include('md.admin@example.com')
    end

    it 'yields no events when Company Admin attempts to filter by an out-of-scope actor' do
      login_as(chs_admin, scope: :user)
      get settings_activity_events_path, params: { actor_id: md_admin.id }

      expect(response.body).not_to include('MD Policy Template')
      expect(response.body).to include('No activity events found')
    end

    context 'with external signer activity events' do
      let(:chs_template) do
        create(:template, account:, company: chs_company, author: chs_admin, name: 'CHS Vendor Agreement')
      end
      let(:chs_submission) { create(:submission, account:, company: chs_company, template: chs_template) }
      let(:chs_signer) do
        create(
          :submitter,
          submission: chs_submission,
          account:,
          company: chs_company,
          name: 'John Signer',
          email: 'john.signer@chs.example.com'
        )
      end

      let(:md_template) do
        create(:template, account:, company: md_company, author: md_admin, name: 'MD Internal Policy')
      end
      let(:md_submission) { create(:submission, account:, company: md_company, template: md_template) }
      let(:md_signer) do
        create(
          :submitter,
          submission: md_submission,
          account:,
          company: md_company,
          name: 'Mary Secret',
          email: 'mary.secret@md.example.com'
        )
      end

      before do
        ActivityEvents.record_submitter_event!(submitter: chs_signer, event_type: 'complete_form')
        ActivityEvents.record_submitter_event!(submitter: md_signer, event_type: 'complete_form')
      end

      it 'allows filtering by external signer using email identifier' do
        get settings_activity_events_path, params: { actor_id: 'email:john.signer@chs.example.com' }

        expect(response.body).to include('John Signer')
        expect(response.body).to include("CHS Vendor Agreement ##{chs_submission.id}")
        expect(response.body).not_to include('MD Internal Policy')
      end

      it 'includes external signers in actor dropdown for authorized scope' do
        get settings_activity_events_path

        expect(response.body).to include('John Signer')
        expect(response.body).to include('Mary Secret')
      end

      it 'never reveals MD signer to CHS Company Admin in dropdown or via filter tampering' do
        login_as(chs_admin, scope: :user)
        get settings_activity_events_path

        expect(response.body).to include('John Signer')
        expect(response.body).not_to include('Mary Secret')
        expect(response.body).not_to include('mary.secret@md.example.com')

        # Tampering with actor_id parameter
        get settings_activity_events_path, params: { actor_id: 'email:mary.secret@md.example.com' }
        expect(response.body).not_to include('MD Internal Policy')
        expect(response.body).to include('No activity events found')
      end
    end

    context 'with email delivery activity events' do
      let(:email_fixtures) do
        chs_template = create(
          :template,
          account:, company: chs_company, author: chs_admin, name: 'CHS Vendor Agreement'
        )
        chs_sub = create(:submission, account:, company: chs_company, template: chs_template)
        chs_signer = create(
          :submitter,
          submission: chs_sub,
          account:,
          company: chs_company,
          name: 'CHS Recipient',
          email: 'recipient@chs.example.com'
        )
        chs_sub_event = SubmissionEvent.create!(submitter: chs_signer, event_type: 'send_email')

        md_template = create(:template, account:, company: md_company, author: md_admin, name: 'MD Internal Policy')
        md_sub = create(:submission, account:, company: md_company, template: md_template)
        md_signer = create(
          :submitter,
          submission: md_sub,
          account:,
          company: md_company,
          name: 'MD Secret Recipient',
          email: 'secret@md.example.com'
        )
        md_sub_event = SubmissionEvent.create!(
          submitter: md_signer,
          event_type: 'send_reminder_email',
          data: { 'slot' => 'first_duration', 'duration' => 'two_days' }
        )

        ActivityEvents.record_submission_email!(
          submitter: chs_signer,
          submission_event: chs_sub_event,
          email_type: :invitation
        )
        ActivityEvents.record_submission_email!(
          submitter: md_signer,
          submission_event: md_sub_event,
          email_type: :reminder,
          metadata: { 'slot' => 'first_duration', 'duration' => 'two_days' }
        )

        { chs_submission: chs_sub, md_submission: md_sub }
      end

      before { email_fixtures }

      it 'allows filtering by action submission.email_sent' do
        get settings_activity_events_path, params: { action_name: 'submission.email_sent' }

        expect(response.body).to include("CHS Vendor Agreement ##{email_fixtures[:chs_submission].id}")
        expect(response.body).to include('To: CHS Recipient &lt;recipient@chs.example.com&gt;')
        expect(response.body).not_to include("MD Internal Policy ##{email_fixtures[:md_submission].id}")
      end

      it 'allows filtering by actor System' do
        get settings_activity_events_path, params: { actor_id: 'name:System' }

        expect(response.body).to include("CHS Vendor Agreement ##{email_fixtures[:chs_submission].id}")
        expect(response.body).to include("MD Internal Policy ##{email_fixtures[:md_submission].id}")
        expect(response.body).not_to include('MD Policy Template')
      end

      it 'prevents CHS Company Admin from seeing MD recipient or MD reminder events' do
        login_as(chs_admin, scope: :user)
        get settings_activity_events_path

        expect(response.body).to include("CHS Vendor Agreement ##{email_fixtures[:chs_submission].id}")
        expect(response.body).to include('recipient@chs.example.com')
        expect(response.body).not_to include('MD Secret Recipient')
        expect(response.body).not_to include('secret@md.example.com')
        expect(response.body).not_to include("MD Internal Policy ##{email_fixtures[:md_submission].id}")
      end
    end
  end
end
