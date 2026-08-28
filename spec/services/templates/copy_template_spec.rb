# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::CopyTemplate do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:chs_company) { create_company(code: 'CHS', name: 'CHS', account: account) }
  let(:md_company) { create_company(code: 'MD', name: 'MD', account: account) }
  let(:other_company) { create_company(code: 'OTH', name: 'Other', account: other_account) }
  let(:platform_admin) { create(:user, platform_admin: true, account: account, company: chs_company) }
  let(:company_admin) { create(:user, platform_admin: false, role: User::ADMIN_ROLE, account: account, company: chs_company) }
  let(:company_viewer) { create(:user, platform_admin: false, role: User::VIEWER_ROLE, account: account, company: chs_company) }
  let(:template) { create(:template, account: account, company: chs_company, author: company_admin) }
  let(:default_folder) { account.default_template_folder }
  let(:chs_department) { create_department(name: 'HR', account: account, company: chs_company) }
  let(:md_department) { create_department(name: 'IT', account: account, company: md_company) }
  let(:chs_folder) { create(:template_folder, account: account, company: chs_company) }
  let(:md_folder) { create(:template_folder, account: account, company: md_company) }

  def create_company(code:, name:, account:)
    Company.find_by(code: code, account_id: account.id) || Company.create!(code: code, name: name, account: account)
  end

  def create_department(name:, company:, account:)
    Department.create!(name: name, company: company, account: account)
  end

  describe '.call' do
    context 'when user is platform_admin' do
      it 'can copy a template from CHS to MD' do
        result = described_class.call(
          template: template,
          target_company: md_company,
          current_user: platform_admin
        )

        expect(result).to be_a(Template)
        expect(result).to be_persisted
        expect(result.company_id).to eq(md_company.id)
        expect(result.id).not_to eq(template.id)
      end

      it 'can assign valid target company departments' do
        result = described_class.call(
          template: template,
          target_company: md_company,
          current_user: platform_admin,
          target_department_ids: [md_department.id]
        )

        expect(result.department_ids).to include(md_department.id)
      end

      it 'rejects department IDs from another company' do
        expect do
          described_class.call(
            template: template,
            target_company: md_company,
            current_user: platform_admin,
            target_department_ids: [chs_department.id]
          )
        end.to raise_error(Templates::CopyTemplate::InvalidTargetError, /must belong to the target company/)
      end

      it 'can assign valid target folder' do
        result = described_class.call(
          template: template,
          target_company: md_company,
          current_user: platform_admin,
          target_folder_id: md_folder.id
        )

        expect(result.folder_id).to eq(md_folder.id)
      end

      it 'rejects target folder from another company' do
        expect do
          described_class.call(
            template: template,
            target_company: md_company,
            current_user: platform_admin,
            target_folder_id: chs_folder.id
          )
        end.to raise_error(Templates::CopyTemplate::InvalidTargetError, /must belong to the target company/)
      end
    end

    context 'when user is company_admin' do
      it 'can copy a template within own company' do
        result = described_class.call(
          template: template,
          target_company: chs_company,
          current_user: company_admin
        )

        expect(result).to be_a(Template)
        expect(result).to be_persisted
        expect(result.company_id).to eq(chs_company.id)
      end

      it 'cannot copy template to another company' do
        expect do
          described_class.call(
            template: template,
            target_company: md_company,
            current_user: company_admin
          )
        end.to raise_error(Templates::CopyTemplate::UnauthorizedError)
      end
    end

    context 'when user is company viewer' do
      it 'cannot copy template' do
        expect do
          described_class.call(
            template: template,
            target_company: chs_company,
            current_user: company_viewer
          )
        end.to raise_error(Templates::CopyTemplate::UnauthorizedError)
      end
    end

    context 'when preserving template data' do
      before do
        user1 = create(:user, account: account, company: chs_company)
        template.template_accesses.create!(user: user1)

        template.update!(
          schema: [{ 'name' => 'Signature', 'type' => 'signature', 'uuid' => SecureRandom.uuid }],
          fields: [{ 'name' => 'Signature', 'uuid' => SecureRandom.uuid, 'submitter_uuid' => 'test' }],
          submitters: [{ 'name' => 'Client', 'uuid' => SecureRandom.uuid }],
          preferences: { 'email_subject' => 'Please sign' },
          name: 'Confidential NDA'
        )
      end

      it 'source template remains unchanged' do
        original_schema = template.schema.dup
        described_class.call(
          template: template,
          target_company: chs_company,
          current_user: company_admin
        )
        expect(template.reload.schema).to eq(original_schema)
      end

      it 'preserves all placed fields/elements, submitters, preferences' do
        result = described_class.call(
          template: template,
          target_company: chs_company,
          current_user: company_admin
        )

        expect(result.schema.size).to eq(1)
        expect(result.schema.first['type']).to eq('signature')
        expect(result.submitters.size).to eq(1)
        expect(result.submitters.first['name']).to eq('Client')
        expect(result.preferences['email_subject']).to eq('Please sign')
        expect(result.name).to include('Confidential NDA')
      end

      it 'safely clones mutable template records' do
        result = described_class.call(
          template: template,
          target_company: chs_company,
          current_user: company_admin
        )

        expect(result.id).not_to eq(template.id)

        expect(template.fields.size).to eq(1)
        expect(result.fields.size).to eq(template.fields.size)
        expect(result.fields.first['uuid']).not_to eq(template.fields.first['uuid'])

        expect(template.submitters.size).to eq(1)
        expect(result.submitters.size).to eq(template.submitters.size)
        expect(result.submitters.first['uuid']).not_to eq(template.submitters.first['uuid'])
      end

      it 'does not retain source template_accesses' do
        expect(template.template_accesses.count).to eq(1)

        result = described_class.call(
          template: template,
          target_company: md_company,
          current_user: platform_admin
        )

        expect(result.template_accesses.count).to eq(0)
      end
    end
  end
end
