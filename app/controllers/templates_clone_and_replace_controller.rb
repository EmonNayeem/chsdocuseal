# frozen_string_literal: true

class TemplatesCloneAndReplaceController < ApplicationController
  load_and_authorize_resource :template

  def create
    return head :unprocessable_content if params[:files].blank?

    ActiveRecord::Associations::Preloader.new(
      records: [@template],
      associations: [{ schema_documents: :preview_images_attachments }]
    ).call

    cloned_template = Templates::Clone.call(@template, author: current_user)
    cloned_template.name = File.basename(params[:files].first.original_filename, '.*')
    cloned_template.company = current_user.company

    authorize!(:create, cloned_template)

    Template.transaction do
      cloned_template.save!
      cloned_template.department_ids = clone_and_replace_department_ids(@template, cloned_template)
    end

    documents = Templates::ReplaceAttachments.call(cloned_template, params, extract_fields: true)

    Templates.maybe_assign_access(cloned_template)

    cloned_template.save!

    Templates::CloneAttachments.call(template: cloned_template, original_template: @template,
                                     excluded_attachment_uuids: documents.map(&:uuid))

    SearchEntries.enqueue_reindex(cloned_template)

    respond_to do |f|
      f.html { redirect_to edit_template_path(cloned_template) }
      f.json { render json: { id: cloned_template.id } }
    end
  rescue Templates::CreateAttachments::PdfEncrypted
    respond_to do |f|
      f.html { render turbo_stream: turbo_stream.append(params[:form_id], html: helpers.tag.prompt_password) }
      f.json { render json: { error: 'PDF encrypted', status: 'pdf_encrypted' }, status: :unprocessable_content }
    end
  end

  private

  def clone_and_replace_department_ids(base_template, cloned_template)
    return [] if base_template.account_id != cloned_template.account_id

    base_template.department_ids
  end
end