# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateVersions::Copy do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:author) { create(:user, account:, company:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, company:, author:) }

  describe '.call' do
    it 'creates a new template from version snapshot with remapped UUIDs and activity log' do
      # Set up template with formula and condition
      v1 = TemplateVersions.find_or_create_for(template, author:)
      v1_doc_uuid = template.schema.first['attachment_uuid']
      v1_blob_id = template.schema_documents.first.blob_id

      # Mutate live template so we verify copy uses version snapshot, not live template
      template.name = 'Live Mutated Name'
      template.save!

      copied_template = nil
      expect do
        copied_template = described_class.call(version: v1, actor: author)
      end.to change(ActivityEvent.where(action: 'template.created'), :count).by(1)

      expect(copied_template).to be_persisted
      expect(copied_template.id).not_to eq(template.id)
      expect(copied_template.name).to eq("#{v1.data['name']} (Version 1 Copy)")
      expect(copied_template.account_id).to eq(account.id)
      expect(copied_template.company_id).to eq(company.id)
      expect(copied_template.folder_id).to eq(template.folder_id)
      expect(copied_template.author_id).to eq(author.id)

      # Assert UUIDs are remapped
      expect(copied_template.submitters.first['uuid']).not_to eq(v1.data['submitters'].first['uuid'])
      expect(copied_template.fields.first['uuid']).not_to eq(v1.data['fields'].first['uuid'])
      new_att_uuid = copied_template.schema.first['attachment_uuid']
      expect(new_att_uuid).not_to eq(v1_doc_uuid)

      # Assert field area attachment_uuid was updated to the new attachment uuid
      field_area = copied_template.fields.first['areas']&.first
      expect(field_area['attachment_uuid']).to eq(new_att_uuid) if field_area

      # Assert source document blob is reused
      expect(copied_template.schema_documents.first.blob_id).to eq(v1_blob_id)

      # Assert ActivityEvent
      event = ActivityEvent.where(action: 'template.created').last
      expect(event.subject_id).to eq(copied_template.id)
      expect(event.metadata['source_template_id']).to eq(template.id)
      expect(event.metadata['source_version_id']).to eq(v1.id)
    end

    it 'copies dynamic documents and attachments referencing historical blobs with new UUIDs' do
      dyn_uuid = SecureRandom.uuid
      template.schema << { 'attachment_uuid' => dyn_uuid, 'name' => 'dynamic', 'dynamic' => true }
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>Dyn</p>')
      img_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('img'),
        filename: 'img.png',
        content_type: 'image/png'
      )
      att = dyn_doc.attachments_attachments.create!(name: 'attachments', blob: img_blob, record: dyn_doc)
      template.save!

      v1 = TemplateVersions.find_or_create_for(template, author:)

      copied = described_class.call(version: v1, actor: author)
      copied_dyn = copied.dynamic_documents.first
      expect(copied_dyn.uuid).not_to eq(dyn_uuid)
      expect(copied_dyn.attachments_attachments.where(blob_id: img_blob.id)).to exist
      expect(copied_dyn.attachments_attachments.first.uuid).not_to eq(att.uuid)
      expect(v1.reload.dynamic_attachments_attachments.where(blob_id: img_blob.id)).to exist
    end
  end
end
