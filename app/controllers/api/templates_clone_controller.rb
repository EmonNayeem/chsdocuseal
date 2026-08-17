# frozen_string_literal: true

module Api
  class TemplatesCloneController < ApiBaseController
    load_and_authorize_resource :template

    def create
      authorize!(:create, @template)

      ActiveRecord::Associations::Preloader.new(
        records: [@template],
        associations: [{ schema_documents: :preview_images_attachments }]
      ).call

      cloned_template = Templates::Clone.call(
        @template,
        author: current_user,
        name: params[:name],
        external_id: params[:external_id].presence || params[:application_key],
        folder_name: params[:folder_name]
      )

      cloned_template.source = :api

      schema_documents = Templates::CloneAttachments.call(template: cloned_template,
                                                          original_template: @template,
                                                          documents: params[:documents])

      Templates.maybe_assign_access(cloned_template)

      Template.transaction do
        cloned_template.save!
        cloned_template.department_ids = api_clone_department_ids(@template, cloned_template)
      end

      WebhookUrls.enqueue_events(cloned_template, 'template.created')

      SearchEntries.enqueue_reindex(cloned_template)

      render json: Templates::SerializeForApi.call(cloned_template, schema_documents:)
    end

    private

    def api_clone_department_ids(base_template, cloned_template)
      return [] if base_template.account_id != cloned_template.account_id

      base_template.department_ids
    end
  end
end
