# frozen_string_literal: true

module TemplateVersions
  class Compare
    FIELD_ATTRIBUTES = %w[
      name type submitter_uuid required readonly default_value
      areas options conditions preferences validation formula
    ].freeze

    def self.call(template:, version:)
      new(template:, version:).call
    end

    def initialize(template:, version:)
      @template = template
      @version = version
    end

    def call
      v_data = @version.data
      current_data = TemplateVersions.build_data(@template)
      identical = (@version.sha1 == Digest::SHA1.hexdigest(current_data.to_json))
      comparison = build_comparison_summary(v_data, identical)

      comparison.merge(
        version: {
          id: @version.id,
          version_number: @version.version_number,
          created_at: @version.created_at,
          author: {
            full_name: @version.author&.full_name,
            email: @version.author&.email
          }
        },
        comparison:,
        visual: {
          historical: visual_payload_for_historical(v_data),
          current: visual_payload_for_current
        }
      )
    end

    private

    def build_comparison_summary(v_data, identical)
      {
        version_id: @version.id,
        version_number: @version.version_number,
        created_at: @version.created_at,
        identical:,
        name: compare_name(v_data),
        documents: compare_documents(v_data),
        parties: compare_parties(v_data),
        fields: compare_fields(v_data),
        preferences: compare_preferences(v_data),
        variables_schema: compare_variables_schema(v_data)
      }
    end

    def visual_payload_for_historical(v_data)
      schema = Array.wrap(v_data['schema'])

      {
        name: v_data['name'],
        schema:,
        submitters: Array.wrap(v_data['submitters']),
        fields: Array.wrap(v_data['fields']),
        documents: serialize_historical_documents(@version, schema),
        dynamic_documents: TemplateVersions.serialize_dynamic_documents(@version, v_data['dynamic_documents'].to_a)
      }
    end

    def visual_payload_for_current
      schema = Array.wrap(@template.schema)

      {
        name: @template.name,
        schema:,
        submitters: Array.wrap(@template.submitters),
        fields: Array.wrap(@template.fields),
        documents: serialize_current_documents(@template, schema),
        dynamic_documents: serialize_current_dynamic_documents(@template, schema)
      }
    end

    def serialize_historical_documents(version, schema)
      schema.reject { |item| item['dynamic'] }.filter_map do |item|
        uuid = item['attachment_uuid']
        doc_att = version.documents_attachments.preload(:blob, preview_images_attachments: :blob).find_by(uuid:)
        if doc_att.nil? && version.documents_attachments.empty?
          doc_att = @template.documents_attachments.preload(:blob, preview_images_attachments: :blob).find_by(uuid:)
        end
        next unless doc_att

        build_document_visual_hash(doc_att, item)
      end
    end

    def serialize_current_documents(template, schema)
      schema.reject { |item| item['dynamic'] }.filter_map do |item|
        uuid = item['attachment_uuid']
        doc_att = template.documents_attachments.preload(:blob, preview_images_attachments: :blob).find_by(uuid:)
        next unless doc_att

        build_document_visual_hash(doc_att, item)
      end
    end

    def build_document_visual_hash(doc_att, schema_item)
      preview_images = doc_att.preview_images_attachments.preload(:blob).map do |pi|
        build_preview_image_hash(pi)
      end
      preview_images.sort_by! { |p| p[:page] }
      preview_images = fallback_preview_images(doc_att) if preview_images.empty?

      {
        id: doc_att.id,
        uuid: doc_att.uuid,
        name: schema_item['name'].presence || 'Document',
        metadata: doc_att.blob&.metadata || {},
        preview_images:
      }
    end

    def build_preview_image_hash(preview_image_att)
      blob = preview_image_att.blob
      filename = blob.filename.to_s
      page = filename[/\d+/].to_i

      {
        id: preview_image_att.id,
        page:,
        filename:,
        url: ActiveStorage::Blob.proxy_url(blob),
        width: blob.metadata['width'] || blob.metadata[:width] || 1400,
        height: blob.metadata['height'] || blob.metadata[:height] || 1812
      }
    end

    def fallback_preview_images(doc_att)
      num_pages = doc_att.blob&.metadata&.dig('pdf', 'number_of_pages') || 1
      (0...num_pages).map do |page|
        {
          id: nil,
          page:,
          filename: "#{page}.png",
          url: nil,
          width: 1400,
          height: 1812
        }
      end
    end

    def serialize_current_dynamic_documents(template, schema)
      dyn_uuids = schema.select { |item| item['dynamic'] }.pluck('attachment_uuid')
      return [] if dyn_uuids.blank?

      template.dynamic_documents.where(uuid: dyn_uuids).order(:id)
              .preload(attachments_attachments: :blob).map do |doc|
        attachments = doc.attachments_attachments.order(:id).map do |att|
          blob = att.blob
          {
            'id' => att.id,
            'uuid' => att.uuid,
            'filename' => blob.filename.to_s,
            'url' => ActiveStorage::Blob.proxy_url(blob)
          }
        end

        {
          'id' => doc.id,
          'uuid' => doc.uuid,
          'body' => doc.body,
          'head' => doc.head,
          'attachments' => attachments
        }
      end
    end

    def compare_name(v_data)
      cur = @template.name.to_s
      ver = v_data['name'].to_s
      {
        current: cur,
        version: ver,
        changed: cur != ver
      }
    end

    def compare_documents(v_data)
      c_docs = Array.wrap(@template.schema)
      v_docs = Array.wrap(v_data['schema'])

      c_map = c_docs.index_by { |d| d['attachment_uuid'] }
      v_map = v_docs.index_by { |d| d['attachment_uuid'] }

      added = (v_map.keys - c_map.keys).map { |u| { 'name' => v_map[u]['name'].presence || 'Document' } }
      removed = (c_map.keys - v_map.keys).map { |u| { 'name' => c_map[u]['name'].presence || 'Document' } }

      changed = changed_documents(c_map, v_map)

      common_c_order = c_docs.pluck('attachment_uuid') & v_map.keys
      common_v_order = v_docs.pluck('attachment_uuid') & c_map.keys
      reordered = common_c_order != common_v_order

      { added:, removed:, changed:, reordered: }
    end

    def changed_documents(c_map, v_map)
      changed = []
      (c_map.keys & v_map.keys).each do |u|
        c_doc = c_map[u]
        v_doc = v_map[u]
        next if c_doc == v_doc

        changed << {
          'name' => v_doc['name'].presence || c_doc['name'].presence || 'Document',
          'current_name' => c_doc['name'],
          'version_name' => v_doc['name']
        }
      end
      changed
    end

    def compare_parties(v_data)
      c_parties = Array.wrap(@template.submitters)
      v_parties = Array.wrap(v_data['submitters'])

      c_map = c_parties.index_by { |p| p['uuid'] }
      v_map = v_parties.index_by { |p| p['uuid'] }

      added = (v_map.keys - c_map.keys).map { |u| { 'name' => v_map[u]['name'].presence || 'Party' } }
      removed = (c_map.keys - v_map.keys).map { |u| { 'name' => c_map[u]['name'].presence || 'Party' } }

      changed = changed_parties(c_map, v_map)

      common_c_order = c_parties.pluck('uuid') & v_map.keys
      common_v_order = v_parties.pluck('uuid') & c_map.keys
      order_changed = common_c_order != common_v_order

      { added:, removed:, changed:, order_changed: }
    end

    def changed_parties(c_map, v_map)
      changed = []
      (c_map.keys & v_map.keys).each do |u|
        c_party = c_map[u]
        v_party = v_map[u]
        next if c_party == v_party

        changed << { 'name' => v_party['name'].presence || c_party['name'].presence || 'Party' }
      end
      changed
    end

    def compare_fields(v_data)
      c_fields = Array.wrap(@template.fields)
      v_fields = Array.wrap(v_data['fields'])

      c_map = c_fields.index_by { |f| f['uuid'] }
      v_map = v_fields.index_by { |f| f['uuid'] }

      added = (v_map.keys - c_map.keys).map do |u|
        f = v_map[u]
        { 'name' => f['name'].presence || 'Untitled Field', 'type' => f['type'] }
      end

      removed = (c_map.keys - v_map.keys).map do |u|
        f = c_map[u]
        { 'name' => f['name'].presence || 'Untitled Field', 'type' => f['type'] }
      end

      changed = changed_fields(c_map, v_map)

      { added:, removed:, changed: }
    end

    def changed_fields(c_map, v_map)
      changed = []
      (c_map.keys & v_map.keys).each do |u|
        c_field = c_map[u]
        v_field = v_map[u]

        diff_keys = detect_field_differences(c_field, v_field)
        next if diff_keys.empty?

        changed << {
          'name' => v_field['name'].presence || c_field['name'].presence || 'Untitled Field',
          'changes' => diff_keys
        }
      end
      changed
    end

    def detect_field_differences(c_field, v_field)
      diff_keys = []
      FIELD_ATTRIBUTES.each do |attr|
        diff_keys << attr.humanize if c_field[attr] != v_field[attr]
      end
      diff_keys
    end

    def compare_preferences(v_data)
      cur = @template.preferences || {}
      ver = v_data['preferences'] || {}
      { changed: cur != ver }
    end

    def compare_variables_schema(v_data)
      cur = @template.variables_schema || []
      ver = v_data['variables_schema'] || []
      { changed: cur != ver }
    end
  end
end
