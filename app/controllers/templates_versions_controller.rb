# frozen_string_literal: true

class TemplatesVersionsController < ApplicationController
  load_and_authorize_resource :template

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: 'Not found' }, status: :not_found
  end

  def index
    versions = @template.template_versions.order(:id).preload(:author).to_a
    serialized = versions.map.with_index do |v, idx|
      v.as_json(TemplateVersions::SERIALIZE_PARAMS).merge(
        'version_number' => idx + 1,
        'documents_count' => Array.wrap(v.data['schema']).size,
        'fields_count' => Array.wrap(v.data['fields']).size,
        'submitters_count' => Array.wrap(v.data['submitters']).size
      )
    end.reverse

    render json: serialized
  end

  def show
    version = @template.template_versions.find(params[:id])

    render json: TemplateVersions.serialize(version)
  end

  def create
    authorize!(:update, @template)

    version = TemplateVersions.find_or_create_for(@template, author: current_user)

    render json: TemplateVersions.serialize(version)
  end

  def compare
    version = @template.template_versions.find(params[:id])

    render json: TemplateVersions::Compare.call(template: @template, version:)
  end

  def restore
    authorize!(:update, @template)

    version = @template.template_versions.find(params[:id])
    TemplateVersions::Restore.call(template: @template, version:, actor: current_user)

    render json: { success: true, redirect_url: edit_template_path(@template) }
  end

  def copy
    authorize_copy_permission!

    version = @template.template_versions.find(params[:id])
    copied = TemplateVersions::Copy.call(version:, actor: current_user, name: params[:name])

    render json: { success: true, id: copied.id, url: edit_template_path(copied) }
  end

  def documents
    version = @template.template_versions.find(params[:id])
    schema_uuids = Array.wrap(version.data['schema']).pluck('attachment_uuid').compact
    docs = version.documents_attachments.where(uuid: schema_uuids)
    docs = @template.documents_attachments.where(uuid: schema_uuids) if docs.empty?

    urls = docs.map do |d|
      ActiveStorage::Blob.proxy_path(d.blob, expires_at: TemplateDocumentsController::FILES_TTL.from_now.to_i)
    end

    render json: urls
  end

  private

  def authorize_copy_permission!
    return if current_user.platform_admin?
    return if current_user.company_admin? && @template.company_id == current_user.company_id

    raise CanCan::AccessDenied, 'You are not authorized to copy this template version.'
  end
end
