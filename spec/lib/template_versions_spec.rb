# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateVersions do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:author) { create(:user, account:, company:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, company:, author:) }

  describe '.build_data' do
    it 'captures full snapshot including preferences and dynamic documents' do
      template.preferences = { 'email_reminders' => { 'enabled' => true } }
      template.save!

      data = described_class.build_data(template)
      expect(data['name']).to eq(template.name)
      expect(data['schema']).to be_an(Array)
      expect(data['submitters']).to be_an(Array)
      expect(data['fields']).to be_an(Array)
      expect(data['preferences']).to eq('email_reminders' => { 'enabled' => true })
      expect(data['dynamic_documents']).to eq([])
    end

    it 'excludes generated URLs and signed tokens from dynamic document snapshot' do
      dyn_uuid = SecureRandom.uuid
      template.schema = [{ 'attachment_uuid' => dyn_uuid, 'name' => 'dynamic-doc', 'dynamic' => true }]
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>Test</p>', head: '<style></style>')
      img_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('png-data'),
        filename: 'image.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: img_blob, record: dyn_doc)
      template.save!

      data = described_class.build_data(template)
      dyn_snap = data['dynamic_documents'].first
      expect(dyn_snap['uuid']).to eq(dyn_uuid)
      att_snap = dyn_snap['attachments'].first
      expect(att_snap['uuid']).to be_present
      expect(att_snap['blob_id']).to eq(img_blob.id)
      expect(att_snap['blob_uuid']).to eq(img_blob.uuid)
      expect(att_snap['checksum']).to eq(img_blob.checksum)
      expect(att_snap['filename']).to eq('image.png')
      expect(att_snap['byte_size']).to eq(img_blob.byte_size)
      expect(att_snap['content_type']).to eq('image/png')
      expect(att_snap).not_to have_key('url')
      expect(att_snap).not_to have_key('signed_key')
    end
  end

  describe '.find_or_create_for' do
    it 'creates a version on first capture' do
      expect do
        described_class.find_or_create_for(template, author:)
      end.to change(TemplateVersion, :count).by(1)

      version = template.template_versions.last
      expect(version.author_id).to eq(author.id)
      expect(version.company_id).to eq(company.id)
      expect(version.account_id).to eq(account.id)
    end

    it 'does NOT create another version if content is identical (deduplication)' do
      described_class.find_or_create_for(template, author:)

      expect do
        described_class.find_or_create_for(template, author:)
      end.not_to change(TemplateVersion, :count)
    end

    it 'creates a new version when a field changes' do
      described_class.find_or_create_for(template, author:)

      template.fields << {
        'uuid' => SecureRandom.uuid,
        'name' => 'Department Added',
        'type' => 'text'
      }
      template.save!

      expect do
        described_class.find_or_create_for(template, author:)
      end.to change(TemplateVersion, :count).by(1)
    end

    it 'creates a new version when preferences change' do
      described_class.find_or_create_for(template, author:)

      template.preferences = { 'custom_setting' => 'new_value' }
      template.save!

      expect do
        described_class.find_or_create_for(template, author:)
      end.to change(TemplateVersion, :count).by(1)
    end

    it 'creates a new version when template document is replaced' do
      described_class.find_or_create_for(template, author:)

      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('spec/fixtures/sample-document.pdf').open,
        filename: 'new-document.pdf',
        content_type: 'application/pdf'
      )
      new_att = ActiveStorage::Attachment.create!(
        blob: new_blob,
        name: :documents,
        record: template
      )
      template.schema = [{ 'attachment_uuid' => new_att.uuid, 'name' => 'new-document' }]
      template.save!

      expect do
        described_class.find_or_create_for(template, author:)
      end.to change(TemplateVersion, :count).by(1)
    end

    it 'preserves identical SHA1 hash across multiple saves with dynamic documents and attachments' do
      dyn_uuid = SecureRandom.uuid
      template.schema = [{ 'attachment_uuid' => dyn_uuid, 'name' => 'dyn-doc', 'dynamic' => true }]
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>Content</p>')
      img_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('img-bytes'),
        filename: 'asset.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: img_blob, record: dyn_doc)
      template.save!

      v1 = described_class.find_or_create_for(template, author:)
      sha1_first = v1.sha1

      # Re-saving identical content must not create a new version
      expect do
        v2 = described_class.find_or_create_for(template, author:)
        expect(v2.id).to eq(v1.id)
        expect(v2.sha1).to eq(sha1_first)
      end.not_to change(TemplateVersion, :count)

      # Replacing the dynamic attachment must create Version 2
      dyn_doc.attachments_attachments.destroy_all
      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('different-img-bytes'),
        filename: 'asset-v2.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: new_blob, record: dyn_doc)

      expect do
        v2 = described_class.find_or_create_for(template, author:)
        expect(v2.id).not_to eq(v1.id)
        expect(v2.sha1).not_to eq(sha1_first)
        expect(v2.version_number).to eq(2)
      end.to change(TemplateVersion, :count).by(1)
    end
  end

  describe 'source document durability and blob reuse' do
    it 'creates version-owned attachment pointing to the same blob without duplicating bytes' do
      version = described_class.find_or_create_for(template, author:)

      original_doc = template.schema_documents.first
      version_doc = version.documents_attachments.find_by(uuid: original_doc.uuid)

      expect(version_doc).to be_present
      expect(version_doc.blob_id).to eq(original_doc.blob_id)

      # Blob count does NOT increase
      expect(ActiveStorage::Blob.where(id: original_doc.blob_id).count).to eq(1)
    end

    it 'retains source document blob when live template replaces its document' do
      version = described_class.find_or_create_for(template, author:)
      original_blob_id = template.schema_documents.first.blob_id

      # Live template replaces document
      template.documents_attachments.destroy_all
      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('spec/fixtures/sample-document.pdf').open,
        filename: 'replacement.pdf',
        content_type: 'application/pdf'
      )
      new_att = ActiveStorage::Attachment.create!(blob: new_blob, name: :documents, record: template)
      template.schema = [{ 'attachment_uuid' => new_att.uuid, 'name' => 'replacement' }]
      template.save!

      # Version 1 still retains its attachment and the original blob exists
      version_doc = version.documents_attachments.first
      expect(version_doc.blob_id).to eq(original_blob_id)
      expect(ActiveStorage::Blob.exists?(original_blob_id)).to be(true)
    end
  end

  describe 'dynamic document attachment durability and retention' do
    it 'retains dynamic attachment blob when live dynamic document attachment is purged' do
      dyn_uuid = SecureRandom.uuid
      template.schema = [{ 'attachment_uuid' => dyn_uuid, 'name' => 'contract', 'dynamic' => true }]
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p><img src="blob:test"/></p>')

      blob_a = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('logo-binary-content'),
        filename: 'logo.png',
        content_type: 'image/png'
      )
      att_a = dyn_doc.attachments_attachments.create!(name: 'attachments', blob: blob_a, record: dyn_doc)

      # 3. Capture Version 1
      v1 = described_class.find_or_create_for(template, author:)

      # 4. Confirm Version 1 owns a durable ActiveStorage reference to blob A without duplicating bytes
      version_att = v1.dynamic_attachments_attachments.find_by(uuid: att_a.uuid)
      expect(version_att).to be_present
      expect(version_att.blob_id).to eq(blob_a.id)
      expect(ActiveStorage::Blob.where(id: blob_a.id).count).to eq(1)

      # 5. Remove/replace the attachment from the LIVE DynamicDocument
      dyn_doc.attachments_attachments.destroy_all
      blob_b = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('new-logo-content'),
        filename: 'new_logo.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: blob_b, record: dyn_doc)
      dyn_doc.update!(body: '<p><img src="blob:new"/></p>')

      # 6. Blob A must still be physically retained in ActiveStorage
      expect(ActiveStorage::Blob.exists?(blob_a.id)).to be(true)

      # 7. Version 1 must still reference original blob, restore it, and copy it
      expect(v1.dynamic_attachments_attachments.where(blob_id: blob_a.id)).to exist

      # Restore
      described_class.restore(template, v1, actor: author)
      restored_dyn = template.reload.dynamic_documents.find_by(uuid: dyn_uuid)
      expect(restored_dyn.attachments_attachments.where(blob_id: blob_a.id)).to exist

      # Copy
      copied = described_class.copy(v1, actor: author)
      copied_dyn = copied.dynamic_documents.find_by(body: dyn_doc.body) || copied.dynamic_documents.first
      expect(copied_dyn.attachments_attachments.where(blob_id: blob_a.id)).to exist
      expect(copied_dyn.attachments_attachments.first.uuid).not_to eq(att_a.uuid)

      # Version 1's attachments remain untouched
      expect(v1.reload.dynamic_attachments_attachments.where(blob_id: blob_a.id)).to exist
    end
  end

  describe '.serialize' do
    it 'injects proxy URLs into dynamic document attachments on serialization' do
      dyn_uuid = SecureRandom.uuid
      template.schema = [{ 'attachment_uuid' => dyn_uuid, 'name' => 'dyn', 'dynamic' => true }]
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>Hi</p>')
      img_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('bytes'),
        filename: 'pic.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob: img_blob, record: dyn_doc)
      template.save!

      v1 = described_class.find_or_create_for(template, author:)
      serialized = described_class.serialize(v1)

      dyn_serialized = serialized['data']['dynamic_documents'].first
      att_serialized = dyn_serialized['attachments'].first
      expect(att_serialized['url']).to be_present
      expect(att_serialized['url']).to include('/file/')
      expect(v1.reload.data['dynamic_documents'].first['attachments'].first).not_to have_key('url')
    end
  end
end
