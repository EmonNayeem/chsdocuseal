# frozen_string_literal: true

module TemplateVersions
  SERIALIZE_PARAMS = {
    only: %i[id created_at],
    include: { author: { only: %i[email], methods: %i[full_name] } }
  }.freeze

  DATA_FIELDS = %i[name schema submitters variables_schema fields preferences].freeze

  module_function

  def find_or_create_for(template, author:)
    data = build_data(template)
    sha1 = Digest::SHA1.hexdigest(data.to_json)

    version = template.template_versions.find_by(sha1:)
    if version
      attach_snapshot_documents!(version, template) if snapshot_attachments_missing?(version, template)
      return version
    end

    version = template.template_versions.create!(
      data:,
      sha1:,
      author:,
      account_id: template.account_id,
      company_id: template.company_id
    )

    attach_snapshot_documents!(version, template)
    version
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def compare(template, version)
    Compare.call(template:, version:)
  end

  def restore(template, version, actor:)
    Restore.call(template:, version:, actor:)
  end

  def copy(version, actor:, name: nil)
    Copy.call(version:, actor:, name:)
  end

  def snapshot_attachments_missing?(version, template)
    (template.schema_documents.present? && version.documents_attachments.empty?) ||
      (template.dynamic_documents.joins(:attachments_attachments).exists? &&
       version.dynamic_attachments_attachments.empty?)
  end

  def attach_snapshot_documents!(version, template)
    template.schema_documents.preload(:blob, preview_images_attachments: :blob).each do |doc|
      version_doc = version.documents_attachments.find_by(uuid: doc.uuid)

      if version_doc.nil?
        version_doc = version.documents_attachments.create!(
          name: 'documents',
          record: version,
          blob_id: doc.blob_id,
          uuid: doc.uuid
        )
      end

      next unless version_doc.preview_images_attachments.empty?

      doc.preview_images_attachments.each do |preview_image|
        version_doc.preview_images_attachments.create!(
          name: 'preview_images',
          record: version_doc,
          blob_id: preview_image.blob_id
        )
      end
    end

    attach_snapshot_dynamic_attachments!(version, template)
  end

  def attach_snapshot_dynamic_attachments!(version, template)
    template.dynamic_documents.preload(attachments_attachments: :blob).each do |doc|
      doc.attachments_attachments.each do |att|
        next if version.dynamic_attachments_attachments.exists?(uuid: att.uuid)

        version.dynamic_attachments_attachments.create!(
          name: 'dynamic_attachments',
          record: version,
          blob_id: att.blob_id,
          uuid: att.uuid
        )
      end
    end
  end

  def serialize(version)
    data = version.data.dup

    data['documents'] = serialize_documents(version, data['schema'].to_a)
    data['dynamic_documents'] = serialize_dynamic_documents(version, data['dynamic_documents'].to_a)

    version.as_json(SERIALIZE_PARAMS).merge(
      'data' => data,
      'version_number' => version.version_number
    )
  end

  def build_data(template)
    dynamic_uuids = template.schema.select { |e| e['dynamic'] }.pluck('attachment_uuid')

    dynamic_documents =
      if dynamic_uuids.present?
        template.dynamic_documents.where(uuid: dynamic_uuids).order(:id)
                .preload(attachments_attachments: :blob).map do |doc|
          attachments_data = doc.attachments_attachments.order(:id).map do |att|
            blob = att.blob
            {
              'uuid' => att.uuid,
              'blob_id' => att.blob_id,
              'blob_uuid' => blob.uuid,
              'checksum' => blob.checksum,
              'filename' => blob.filename.to_s,
              'byte_size' => blob.byte_size,
              'content_type' => blob.content_type
            }
          end
          doc.as_json(only: %i[uuid body head]).merge('attachments' => attachments_data)
        end
      else
        []
      end

    data = template.as_json(only: DATA_FIELDS)
    data['preferences'] ||= {}
    data['dynamic_documents'] = dynamic_documents
    data
  end

  def serialize_documents(version, schema)
    return [] if schema.blank?

    docs = version.documents_attachments.where(uuid: schema.pluck('attachment_uuid'))
    docs = version.template.documents_attachments.where(uuid: schema.pluck('attachment_uuid')) if docs.empty?

    docs.preload(:blob, preview_images_attachments: :blob).as_json(
      only: %i[id uuid],
      methods: %i[metadata signed_key],
      include: { preview_images: { only: %i[id], methods: %i[url metadata filename] } }
    )
  end

  def serialize_dynamic_documents(version, dynamic_docs)
    return [] if dynamic_docs.blank?

    version_attachments = version.dynamic_attachments_attachments.preload(:blob).index_by(&:uuid)

    dynamic_docs.map do |attrs|
      doc_data = attrs.deep_dup
      raw_attachments = doc_data['attachments']

      if raw_attachments.present?
        doc_data['attachments'] = raw_attachments.map do |att_data|
          att = version_attachments[att_data['uuid']]
          blob = att&.blob
          blob ||= ActiveStorage::Blob.find_by(id: att_data['blob_id']) if att_data['blob_id']
          blob ||= ActiveStorage::Blob.find_by(uuid: att_data['blob_uuid']) if att_data['blob_uuid']

          url = blob ? ActiveStorage::Blob.proxy_url(blob) : nil
          att_data.merge('url' => url)
        end
      else
        doc = version.template.dynamic_documents.find_by(uuid: attrs['uuid'])
        if doc
          attachments_data = doc.attachments_attachments.as_json(only: %i[uuid], methods: %i[url metadata filename])
          doc_data = doc_data.merge('head' => doc.head, 'attachments' => attachments_data)
        end
      end

      doc_data
    end
  end
end
