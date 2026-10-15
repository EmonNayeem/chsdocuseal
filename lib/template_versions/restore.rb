# frozen_string_literal: true

module TemplateVersions
  class Restore
    def self.call(template:, version:, actor:)
      new(template:, version:, actor:).call
    end

    def initialize(template:, version:, actor:)
      @template = template
      @version = version
      @actor = actor
    end

    def call
      raise ArgumentError, 'Version does not belong to template' if @version.template_id != @template.id

      v_data = @version.data
      old_name = @template.name

      Template.transaction do
        apply_versioned_attributes!(v_data)
        restore_documents!
        restore_dynamic_documents!(v_data['dynamic_documents'])

        @template.save!

        SearchEntries.enqueue_reindex(@template) if defined?(SearchEntries) && old_name != @template.name
        WebhookUrls.enqueue_events(@template, 'template.updated') if defined?(WebhookUrls)

        record_restore_activity!
      end

      @template
    end

    private

    def apply_versioned_attributes!(v_data)
      @template.name = v_data['name']
      @template.schema = v_data['schema'].deep_dup
      @template.submitters = v_data['submitters'].deep_dup
      @template.fields = v_data['fields'].deep_dup
      @template.variables_schema = v_data['variables_schema'].deep_dup
      @template.preferences = (v_data['preferences'] || {}).deep_dup
    end

    def record_restore_activity!
      ActivityEvents.record!(
        actor: @actor,
        action: 'template.version_restored',
        subject: @template,
        metadata: {
          'version_id' => @version.id,
          'version_number' => @version.version_number
        }
      )
    end

    def restore_documents!
      schema_uuids = Array.wrap(@template.schema).pluck('attachment_uuid').compact
      @template.documents_attachments.where.not(uuid: schema_uuids).destroy_all

      version_docs = @version.documents_attachments.preload(:blob, preview_images_attachments: :blob).index_by(&:uuid)

      schema_uuids.each do |uuid|
        current_att = @template.documents_attachments.find_by(uuid:)
        version_doc = version_docs[uuid]

        if current_att
          update_attachment_if_needed!(current_att, version_doc)
        elsif version_doc
          create_attachment_from_version!(version_doc)
        end
      end
    end

    def update_attachment_if_needed!(current_att, version_doc)
      return unless version_doc && current_att.blob_id != version_doc.blob_id

      current_att.update!(blob_id: version_doc.blob_id)
      current_att.preview_images_attachments.destroy_all
      version_doc.preview_images_attachments.each do |pi|
        current_att.preview_images_attachments.create!(
          name: 'preview_images',
          record: current_att,
          blob_id: pi.blob_id
        )
      end
    end

    def create_attachment_from_version!(version_doc)
      new_doc = @template.documents_attachments.create!(
        name: 'documents',
        record: @template,
        blob_id: version_doc.blob_id,
        uuid: version_doc.uuid
      )
      version_doc.preview_images_attachments.each do |pi|
        new_doc.preview_images_attachments.create!(
          name: 'preview_images',
          record: new_doc,
          blob_id: pi.blob_id
        )
      end
    end

    def restore_dynamic_documents!(dynamic_docs_data)
      dynamic_docs_data = Array.wrap(dynamic_docs_data)
      dynamic_uuids = dynamic_docs_data.pluck('uuid').compact

      @template.dynamic_documents.where.not(uuid: dynamic_uuids).destroy_all

      dynamic_docs_data.each do |data|
        doc = @template.dynamic_documents.find_or_initialize_by(uuid: data['uuid'])
        doc.body = data['body'] || ''
        doc.head = data['head']
        doc.save!

        restore_dynamic_document_attachments!(doc, data['attachments'])
      end
    end

    def restore_dynamic_document_attachments!(doc, attachments_data)
      target_attachments = Array.wrap(attachments_data)
      target_uuids = target_attachments.pluck('uuid').compact

      doc.attachments_attachments.where.not(uuid: target_uuids).destroy_all

      target_attachments.each do |att_data|
        blob_id = att_data['blob_id']
        blob_id ||= @version.dynamic_attachments_attachments.find_by(uuid: att_data['uuid'])&.blob_id
        next unless blob_id

        current_att = doc.attachments_attachments.find_by(uuid: att_data['uuid'])
        if current_att
          current_att.update!(blob_id:) if current_att.blob_id != blob_id
        else
          doc.attachments_attachments.create!(
            name: 'attachments',
            record: doc,
            blob_id:,
            uuid: att_data['uuid']
          )
        end
      end
    end
  end
end
