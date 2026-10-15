# frozen_string_literal: true

module TemplateVersions
  class Copy
    def self.call(version:, actor:, name: nil)
      new(version:, actor:, name:).call
    end

    def initialize(version:, actor:, name: nil)
      @version = version
      @actor = actor
      @name = name
    end

    def call
      v_data = @version.data
      original_template = @version.template
      copied_template = build_template(v_data, original_template)
      schema_uuids_replacements = remap_schema_and_fields!(copied_template)

      Template.transaction do
        copied_template.save!
        attach_version_documents!(copied_template, original_template, schema_uuids_replacements)
        copy_dynamic_documents!(copied_template, v_data, schema_uuids_replacements)
        copy_accesses!(copied_template, original_template)
        record_copy_activity!(copied_template, original_template)

        SearchEntries.enqueue_reindex(copied_template) if defined?(SearchEntries)
        WebhookUrls.enqueue_events(copied_template, 'template.created') if defined?(WebhookUrls)
      end

      copied_template
    end

    private

    def build_template(v_data, original_template)
      copied = original_template.account.templates.new(
        company: original_template.company,
        folder_id: original_template.folder_id,
        author: @actor,
        shared_link: original_template.shared_link,
        variables_schema: (v_data['variables_schema'] || []).deep_dup,
        name: @name.presence || "#{v_data['name']} (Version #{@version.version_number} Copy)"
      )

      apply_cloned_attributes!(copied, v_data)
      copied
    end

    def apply_cloned_attributes!(copied, v_data)
      submitters, fields, schema, preferences =
        Templates::Clone.update_submitters_and_fields_and_schema(
          (v_data['submitters'] || []).deep_dup,
          (v_data['fields'] || []).deep_dup,
          (v_data['schema'] || []).deep_dup,
          (v_data['preferences'] || {}).deep_dup
        )

      copied.submitters = submitters
      copied.fields = fields
      copied.schema = schema
      copied.preferences = preferences
    end

    def remap_schema_and_fields!(copied)
      replacements = {}
      copied.schema.each do |schema_item|
        new_uuid = SecureRandom.uuid
        replacements[schema_item['attachment_uuid']] = new_uuid
        schema_item['attachment_uuid'] = new_uuid
      end

      copied.fields.each do |field|
        next if field['areas'].blank?

        field['areas'].each do |area|
          new_uuid = replacements[area['attachment_uuid']]
          area['attachment_uuid'] = new_uuid if new_uuid
        end
      end

      replacements
    end

    def attach_version_documents!(copied, original_template, replacements)
      version_docs = @version.documents_attachments.presence || original_template.schema_documents
      version_docs.preload(:blob, preview_images_attachments: :blob).each do |doc|
        new_att_uuid = replacements[doc.uuid]
        next unless new_att_uuid

        new_doc = copied.documents_attachments.create!(
          name: 'documents',
          record: copied,
          blob_id: doc.blob_id,
          uuid: new_att_uuid
        )

        doc.preview_images_attachments.each do |pi|
          new_doc.preview_images_attachments.create!(
            name: 'preview_images',
            record: new_doc,
            blob_id: pi.blob_id
          )
        end
      end
    end

    def copy_dynamic_documents!(copied, v_data, replacements)
      version_attachments = @version.dynamic_attachments_attachments.index_by(&:uuid)

      Array.wrap(v_data['dynamic_documents']).each do |dyn_data|
        new_dyn_uuid = replacements[dyn_data['uuid']] || SecureRandom.uuid
        body = (dyn_data['body'] || '').dup

        att_replacements = {}
        Array.wrap(dyn_data['attachments']).each do |att_data|
          att_replacements[att_data['uuid']] = SecureRandom.uuid
        end

        att_replacements.each do |old_u, new_u|
          body.gsub!(old_u, new_u)
        end

        copied_doc = copied.dynamic_documents.create!(
          uuid: new_dyn_uuid,
          body:,
          head: dyn_data['head']
        )

        Array.wrap(dyn_data['attachments']).each do |att_data|
          blob_id = att_data['blob_id'] || version_attachments[att_data['uuid']]&.blob_id
          next unless blob_id

          new_att_uuid = att_replacements[att_data['uuid']]
          copied_doc.attachments_attachments.create!(
            name: 'attachments',
            record: copied_doc,
            blob_id:,
            uuid: new_att_uuid
          )
        end
      end
    end

    def copy_accesses!(copied, original_template)
      original_template.template_accesses.each do |access|
        copied.template_accesses.create!(user_id: access.user_id)
      end
    end

    def record_copy_activity!(copied, original_template)
      ActivityEvents.record!(
        actor: @actor,
        action: 'template.created',
        subject: copied,
        metadata: {
          'source_template_id' => original_template.id,
          'source_version_id' => @version.id
        }
      )
    end
  end
end
