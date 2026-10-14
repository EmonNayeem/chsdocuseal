# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityEvent, type: :model do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:other_company) { account.companies.find_by!(code: 'MD') }
  let(:actor) { create(:user, account:, company:) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      event = described_class.new(
        account:,
        action: 'recipient_contact.created',
        subject_type: 'RecipientContact',
        subject_id: 1,
        subject_label: 'Test Contact <test@example.com>',
        visibility_scope: 'account',
        occurred_at: Time.current
      )
      expect(event).to be_valid
    end

    it 'requires account' do
      event = described_class.new(account: nil)
      expect(event).not_to be_valid
      expect(event.errors[:account]).to be_present
    end

    it 'requires action' do
      event = described_class.new(action: nil)
      expect(event).not_to be_valid
      expect(event.errors[:action]).to be_present
    end

    it 'requires subject_type' do
      event = described_class.new(subject_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:subject_type]).to be_present
    end

    it 'requires subject_label' do
      event = described_class.new(subject_label: nil)
      expect(event).not_to be_valid
      expect(event.errors[:subject_label]).to be_present
    end

    it 'requires valid visibility_scope' do
      event = described_class.new(visibility_scope: 'invalid')
      expect(event).not_to be_valid
      expect(event.errors[:visibility_scope]).to be_present
    end

    it 'requires company_id when visibility_scope is company' do
      event = described_class.new(
        account:,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Form A',
        visibility_scope: 'company',
        company_id: nil,
        occurred_at: Time.current
      )
      expect(event).not_to be_valid
      expect(event.errors[:company_id]).to be_present
    end

    it 'allows nil company_id when visibility_scope is account' do
      event = described_class.new(
        account:,
        action: 'recipient_contact.created',
        subject_type: 'RecipientContact',
        subject_label: 'Shared Contact',
        visibility_scope: 'account',
        company_id: nil,
        occurred_at: Time.current
      )
      expect(event).to be_valid
    end

    it 'validates company belongs to the same account' do
      other_account = create(:account)
      other_account_company = other_account.companies.first
      event = described_class.new(
        account:,
        company: other_account_company,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Form A',
        visibility_scope: 'company',
        occurred_at: Time.current
      )
      expect(event).not_to be_valid
      expect(event.errors[:company_id]).to be_present
    end

    it 'validates actor belongs to the same account' do
      other_account_user = create(:user)
      event = described_class.new(
        account:,
        actor_user: other_account_user,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Form A',
        visibility_scope: 'account',
        occurred_at: Time.current
      )
      expect(event).not_to be_valid
      expect(event.errors[:actor_user_id]).to be_present
    end
  end

  describe 'durability on association removal' do
    it 'nullifies company_id when company is destroyed without deleting the event' do
      target_company = account.companies.find_by!(code: 'SL')
      event = described_class.create!(
        account:,
        company: target_company,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Template 1',
        visibility_scope: 'company',
        occurred_at: Time.current
      )

      target_company.destroy!
      event.reload
      expect(event.company_id).to be_nil
      expect(event).to be_persisted
    end

    it 'nullifies actor_user_id when actor user is destroyed without deleting the event' do
      event = described_class.create!(
        account:,
        actor_user: actor,
        actor_name: actor.full_name,
        actor_email: actor.email,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Template 1',
        visibility_scope: 'account',
        occurred_at: Time.current
      )

      actor.destroy!
      event.reload
      expect(event.actor_user_id).to be_nil
      expect(event.actor_name).to eq(actor.full_name)
      expect(event.actor_email).to eq(actor.email)
      expect(event).to be_persisted
    end
  end

  describe '.visible_to' do
    let(:platform_admin) { create(:user, account:, company:, platform_admin: true) }
    let(:company_admin) { create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: false) }
    let(:editor) { create(:user, account:, company:, role: User::EDITOR_ROLE, platform_admin: false) }
    let(:viewer) { create(:user, account:, company:, role: User::VIEWER_ROLE, platform_admin: false) }

    let!(:own_company_event) do
      described_class.create!(
        account:,
        company:,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Own Company Form',
        visibility_scope: 'company',
        occurred_at: Time.current
      )
    end

    let!(:other_company_event) do
      described_class.create!(
        account:,
        company: other_company,
        action: 'template.created',
        subject_type: 'Template',
        subject_label: 'Other Company Form',
        visibility_scope: 'company',
        occurred_at: Time.current
      )
    end

    let!(:account_scoped_event) do
      described_class.create!(
        account:,
        action: 'recipient_contact.created',
        subject_type: 'RecipientContact',
        subject_label: 'Shared Recipient',
        visibility_scope: 'account',
        occurred_at: Time.current
      )
    end

    let!(:other_account_event) do
      other_acc = create(:account)
      described_class.create!(
        account: other_acc,
        action: 'recipient_contact.created',
        subject_type: 'RecipientContact',
        subject_label: 'External Recipient',
        visibility_scope: 'account',
        occurred_at: Time.current
      )
    end

    it 'allows platform admin to see all events in their account' do
      events = described_class.visible_to(platform_admin)
      expect(events).to include(own_company_event, other_company_event, account_scoped_event)
      expect(events).not_to include(other_account_event)
    end

    it 'allows company admin to see own company events and account-scoped events only' do
      events = described_class.visible_to(company_admin)
      expect(events).to include(own_company_event, account_scoped_event)
      expect(events).not_to include(other_company_event)
      expect(events).not_to include(other_account_event)
    end

    it 'denies editors access' do
      expect(described_class.visible_to(editor)).to be_empty
    end

    it 'denies viewers access' do
      expect(described_class.visible_to(viewer)).to be_empty
    end

    it 'returns empty when user is nil' do
      expect(described_class.visible_to(nil)).to be_empty
    end
  end
end
