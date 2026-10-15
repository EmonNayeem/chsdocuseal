# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateVersions::Restore do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:author) { create(:user, account:, company:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, company:, author:) }

  describe '.call' do
    it 'restores versioned attributes and document blobs while preserving tenancy and submissions' do
      template.preferences = { 'email_reminders' => { 'enabled' => true } }
      template.save!

      # Capture Version 1
      v1 = TemplateVersions.find_or_create_for(template, author:)
      v1_blob_id = template.schema_documents.first.blob_id
      v1_name = template.name
      v1_fields = template.fields.deep_dup

      # Create an existing Submission against Version 1
      submission = create(:submission, :with_submitters, template:, account:)
      sub_submitter = submission.submitters.first

      # Mutate live Template (Version 2 state)
      template.name = 'V2 Name'
      template.preferences = { 'email_reminders' => { 'enabled' => false } }
      template.fields << { 'uuid' => SecureRandom.uuid, 'name' => 'V2 Field', 'type' => 'text' }

      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('spec/fixtures/sample-document.pdf').open,
        filename: 'v2-doc.pdf',
        content_type: 'application/pdf'
      )
      new_att = ActiveStorage::Attachment.create!(blob: new_blob, name: :documents, record: template)
      template.schema = [{ 'attachment_uuid' => new_att.uuid, 'name' => 'v2-doc' }]
      template.save!

      # Tenancy / ownership baseline
      original_account_id = template.account_id
      original_company_id = template.company_id
      original_folder_id = template.folder_id
      original_author_id = template.author_id

      # Execute Restore of Version 1
      expect do
        described_class.call(template:, version: v1, actor: author)
      end.to change(ActivityEvent.where(action: 'template.version_restored'), :count).by(1)

      template.reload

      # Assert attributes restored
      expect(template.name).to eq(v1_name)
      expect(template.preferences).to eq('email_reminders' => { 'enabled' => true })
      expect(template.fields).to eq(v1_fields)
      expect(template.schema_documents.first.blob_id).to eq(v1_blob_id)

      # Assert tenancy & ownership untouched
      expect(template.account_id).to eq(original_account_id)
      expect(template.company_id).to eq(original_company_id)
      expect(template.folder_id).to eq(original_folder_id)
      expect(template.author_id).to eq(original_author_id)

      # Assert existing submission remains unchanged
      submission.reload
      expect(submission.template_id).to eq(template.id)
      expect(submission.submitters.first.id).to eq(sub_submitter.id)

      # Assert ActivityEvent metadata
      event = ActivityEvent.where(action: 'template.version_restored').last
      expect(event.subject_id).to eq(template.id)
      expect(event.actor_user_id).to eq(author.id)
      expect(event.metadata['version_id']).to eq(v1.id)
      expect(event.metadata['version_number']).to eq(1)
    end

    it 'raises error and does NOT record ActivityEvent when version does not belong to template' do
      other_template = create(:template, account:, company:, author:)
      other_version = TemplateVersions.find_or_create_for(other_template, author:)

      expect do
        described_class.call(template:, version: other_version, actor: author)
      end.to raise_error(ArgumentError, /Version does not belong to template/)

      expect(ActivityEvent.where(action: 'template.version_restored')).to be_empty
    end

    it 'restores dynamic documents and attachments referencing historical blobs' do
      dyn_uuid = SecureRandom.uuid
      template.schema << { 'attachment_uuid' => dyn_uuid, 'name' => 'dynamic-contract', 'dynamic' => true }
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>V1 body</p>')
      blob_v1 = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('v1-logo'),
        filename: 'v1_logo.png',
        content_type: 'image/png'
      )
      att_v1 = dyn_doc.attachments_attachments.create!(name: 'attachments', blob: blob_v1, record: dyn_doc)
      template.save!

      v1 = TemplateVersions.find_or_create_for(template, author:)

      # Mutate live template dynamic document: replace attachment and body
      dyn_doc.attachments_attachments.destroy_all
      blob_v2 = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('v2-logo'),
        filename: 'v2_logo.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: blob_v2, record: dyn_doc)
      dyn_doc.update!(body: '<p>V2 body</p>')

      # Restore V1
      described_class.call(template:, version: v1, actor: author)
      template.reload

      restored_dyn = template.dynamic_documents.find_by(uuid: dyn_uuid)
      expect(restored_dyn.body).to eq('<p>V1 body</p>')
      expect(restored_dyn.attachments_attachments.where(blob_id: blob_v1.id)).to exist
      expect(restored_dyn.attachments_attachments.first.uuid).to eq(att_v1.uuid)
      expect(v1.reload.dynamic_attachments_attachments.where(blob_id: blob_v1.id)).to exist
    end
  end
end
