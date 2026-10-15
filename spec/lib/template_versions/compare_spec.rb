# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateVersions::Compare do
  let(:account) { create(:account) }
  let(:company) { account.companies.find_by!(code: 'CHS') }
  let(:author) { create(:user, account:, company:, role: User::ADMIN_ROLE) }
  let(:template) { create(:template, account:, company:, author:) }

  describe '.call' do
    it 'returns identical: true when template matches version' do
      version = TemplateVersions.find_or_create_for(template, author:)
      diff = described_class.call(template:, version:)

      expect(diff[:identical]).to be(true)
      expect(diff[:version_number]).to eq(1)
      expect(diff[:name][:changed]).to be(false)
      expect(diff[:preferences][:changed]).to be(false)
      expect(diff[:variables_schema][:changed]).to be(false)
    end

    it 'detects name change' do
      version = TemplateVersions.find_or_create_for(template, author:)
      template.update!(name: 'Renamed Template')

      diff = described_class.call(template:, version:)
      expect(diff[:identical]).to be(false)
      expect(diff[:name][:changed]).to be(true)
      expect(diff[:name][:current]).to eq('Renamed Template')
      expect(diff[:name][:version]).to eq(version.data['name'])
    end

    it 'detects field differences with human-friendly change summary' do
      version = TemplateVersions.find_or_create_for(template, author:)

      field = template.fields.first
      field['name'] = 'Updated Field Name'
      field['required'] = !field['required']
      template.save!

      diff = described_class.call(template:, version:)
      expect(diff[:identical]).to be(false)
      expect(diff[:fields][:changed].size).to eq(1)

      changed_field = diff[:fields][:changed].first
      expect(changed_field['changes']).to include('Name', 'Required')
    end

    it 'detects party differences' do
      version = TemplateVersions.find_or_create_for(template, author:)

      template.submitters << { 'uuid' => SecureRandom.uuid, 'name' => 'Approver Party' }
      template.save!

      diff = described_class.call(template:, version:)
      expect(diff[:parties][:removed]).to include('name' => 'Approver Party')
    end

    it 'detects document differences' do
      version = TemplateVersions.find_or_create_for(template, author:)

      template.schema.first['name'] = 'renamed-doc'
      template.save!

      diff = described_class.call(template:, version:)
      expect(diff[:documents][:changed]).to include(hash_including('current_name' => 'renamed-doc'))
    end

    it 'detects preferences change' do
      version = TemplateVersions.find_or_create_for(template, author:)

      template.preferences = { 'test_pref' => true }
      template.save!

      diff = described_class.call(template:, version:)
      expect(diff[:preferences][:changed]).to be(true)
    end
  end

  describe 'visual comparison payloads' do
    it 'includes visual payload with historical and current structures' do
      version = TemplateVersions.find_or_create_for(template, author:)
      diff = described_class.call(template:, version:)

      expect(diff).to have_key(:visual)
      expect(diff[:visual]).to have_key(:historical)
      expect(diff[:visual]).to have_key(:current)

      hist = diff[:visual][:historical]
      curr = diff[:visual][:current]

      expect(hist[:name]).to eq(template.name)
      expect(curr[:name]).to eq(template.name)
      expect(hist[:documents]).to be_an(Array)
      expect(curr[:documents]).to be_an(Array)
    end

    it 'isolates historical documents when live template PDF is replaced' do
      v1 = TemplateVersions.find_or_create_for(template, author:)
      orig_doc = template.schema_documents.first
      orig_uuid = orig_doc.uuid
      orig_blob_id = orig_doc.blob_id

      # Replace live template document
      template.documents_attachments.destroy_all
      new_blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('spec/fixtures/sample-document.pdf').open,
        filename: 'replacement.pdf',
        content_type: 'application/pdf'
      )
      new_att = ActiveStorage::Attachment.create!(blob: new_blob, name: :documents, record: template)
      template.schema = [{ 'attachment_uuid' => new_att.uuid, 'name' => 'replacement' }]
      template.save!

      diff = described_class.call(template:, version: v1)
      hist = diff[:visual][:historical]
      curr = diff[:visual][:current]

      # Historical visual points to original document attachment and blob
      expect(hist[:documents].first[:uuid]).to eq(orig_uuid)
      expect(v1.documents_attachments.find_by(uuid: orig_uuid).blob_id).to eq(orig_blob_id)

      # Current visual points to replacement document attachment and blob
      expect(curr[:documents].first[:uuid]).to eq(new_att.uuid)
      expect(curr[:documents].first[:id]).to eq(new_att.id)
    end

    it 'serializes preview image metadata correctly' do
      version = TemplateVersions.find_or_create_for(template, author:)
      diff = described_class.call(template:, version:)
      hist_doc = diff[:visual][:historical][:documents].first
      expect(hist_doc[:preview_images]).to be_present

      pi = hist_doc[:preview_images].first
      expect(pi[:page]).to eq(0)
      expect(pi[:filename]).to eq('0.png')
      expect(pi[:url]).to include('/file/')
      expect(pi[:width]).to eq(1400)
      expect(pi[:height]).to eq(1981)
    end

    it 'serializes dynamic document visual payload with historical snapshot on left and live on right' do
      dyn_uuid = SecureRandom.uuid
      template.schema = [{ 'attachment_uuid' => dyn_uuid, 'name' => 'contract', 'dynamic' => true }]
      dyn_doc = template.dynamic_documents.create!(uuid: dyn_uuid, body: '<p>Historical Body</p>')
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('img-data'),
        filename: 'v1.png',
        content_type: 'image/png'
      )
      dyn_doc.attachments_attachments.create!(name: 'attachments', blob:, record: dyn_doc)
      template.save!

      v1 = TemplateVersions.find_or_create_for(template, author:)

      # Update live dynamic document
      dyn_doc.update!(body: '<p>Updated Current Body</p>')

      diff = described_class.call(template:, version: v1)
      hist_dyn = diff[:visual][:historical][:dynamic_documents].first
      curr_dyn = diff[:visual][:current][:dynamic_documents].first

      expect(hist_dyn['body']).to eq('<p>Historical Body</p>')
      expect(curr_dyn['body']).to eq('<p>Updated Current Body</p>')
      expect(hist_dyn['attachments'].first['url']).to include('/file/')
    end

    it 'ensures generated URLs are never persisted in TemplateVersion#data or canonical SHA1' do
      version = TemplateVersions.find_or_create_for(template, author:)
      original_sha1 = version.sha1

      # Call compare multiple times
      described_class.call(template:, version:)
      described_class.call(template:, version:)

      version.reload
      expect(version.sha1).to eq(original_sha1)
      expect(version.data.to_json).not_to include('/file/')
      expect(version.data.to_json).not_to include('rails/active_storage')
    end
  end
end
