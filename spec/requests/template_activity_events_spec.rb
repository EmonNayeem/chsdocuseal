# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Activity Events', type: :request do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:admin) do
    create(:user, account:, company:, role: User::ADMIN_ROLE, platform_admin: true)
  end
  let(:template) { create(:template, account:, company:, author: admin) }

  before { login_as(admin, scope: :user) }

  describe 'Template lifecycle activity logging' do
    it 'logs template.created on template creation' do
      expect do
        post templates_path, params: {
          template: { name: 'Audit Test Template' }
        }
      end.to change(ActivityEvent.where(action: 'template.created'), :count).by(1)

      event = ActivityEvent.where(action: 'template.created').last
      expect(event.subject_label).to eq('Audit Test Template')
      expect(event.actor_user_id).to eq(admin.id)
      expect(event.company_id).to eq(company.id)
    end

    it 'does NOT log ActivityEvent on normal/autosave template updates' do
      expect do
        patch template_path(template), params: {
          template: { name: 'Autosaved Form Name' }
        }
        put template_path(template), params: {
          template: { name: 'Second Autosave Name' }
        }
      end.not_to change(ActivityEvent, :count)
    end

    it 'logs template.updated ActivityEvent on explicit Save button click' do
      expect do
        put template_path(template), params: {
          template: { name: 'Explicitly Saved Template' },
          record_activity: true
        }
      end.to change(ActivityEvent.where(action: 'template.updated'), :count).by(1)

      event = ActivityEvent.where(action: 'template.updated').last
      expect(event.subject_id).to eq(template.id)
      expect(event.subject_label).to eq('Explicitly Saved Template')
      expect(event.actor_user_id).to eq(admin.id)
      expect(event.company_id).to eq(company.id)
      expect(event.visibility_scope).to eq('company')
    end

    it 'does NOT log template.updated if explicit update fails validation' do
      allow_any_instance_of(Template).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(template))

      expect do
        put template_path(template), params: {
          template: { name: 'Invalid Template' },
          record_activity: true
        }
      rescue ActiveRecord::RecordInvalid
        # rescued in test
      end.not_to change(ActivityEvent, :count)
    end

    it 'logs template.archived on soft deletion' do
      expect do
        delete template_path(template)
      end.to change(ActivityEvent.where(action: 'template.archived'), :count).by(1)

      event = ActivityEvent.where(action: 'template.archived').last
      expect(event.subject_id).to eq(template.id)
      expect(event.subject_label).to eq(template.name)
    end

    it 'logs template.deleted on permanent deletion and survives subject destroy' do
      template_id = template.id
      template_name = template.name

      expect do
        delete template_path(template), params: { permanently: 'true' }
      end.to change(ActivityEvent.where(action: 'template.deleted'), :count).by(1)

      event = ActivityEvent.where(action: 'template.deleted').last
      expect(event.subject_id).to eq(template_id)
      expect(event.subject_label).to eq(template_name)
      expect(Template.find_by(id: template_id)).to be_nil
    end
  end
end
