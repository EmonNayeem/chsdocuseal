# frozen_string_literal: true

class TemplatesController < ApplicationController
  load_and_authorize_resource :template

  def template_create_department_ids(raw_ids)
    submitted_ids = Array(raw_ids).compact_blank

    if current_user.department_acl_admin?
      if current_user.platform_admin?
        current_account.departments.where(id: submitted_ids).pluck(:id)
      else
        current_account.departments.where(id: submitted_ids, company_id: current_user.company_id).pluck(:id)
      end
    elsif submitted_ids.present?
      current_user.departments.where(id: submitted_ids).pluck(:id)
    else
      current_user.department_ids
    end
  end

  def show
    submissions = @template.submissions.accessible_by(current_ability)
    submissions = submissions.active if @template.archived_at.blank?
    submissions = Submissions.search(current_user, submissions, params[:q], search_values: true)
    submissions = Submissions::Filter.call(submissions, current_user, params.except(:status))

    @base_submissions = submissions

    submissions = Submissions::Filter.filter_by_status(submissions, params)

    submissions = if params[:completed_at_from].present? || params[:completed_at_to].present?
                    submissions.order(completed_at: :desc)
                  else
                    submissions.order(id: :desc)
                  end

    @pagy, @submissions =
      pagy_auto(submissions.select_for_list.preload(:template_accesses, submitters: :start_form_submission_events))
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path
  end

  def new; end

  def edit
    @template_data = Templates.serialize_for_builder(@template)

    render :edit, layout: 'plain'
  end

  def create
    @template.author = current_user
    @template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
    @template.account = current_account
    @template.company = current_user.company

    Templates.maybe_assign_access(@template)

    assign_create_preferences(@template)

    department_ids = template_create_department_ids(params.dig(:template, :department_ids))

    Template.transaction do
      @template.save!
      @template.department_ids = department_ids
    end

    SearchEntries.enqueue_reindex(@template)
    WebhookUrls.enqueue_events(@template, 'template.created')

    redirect_to(edit_template_path(@template))
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: turbo_stream.replace(:modal, template: 'templates/new'), status: :unprocessable_content
  end

  def update
    @template.assign_attributes(template_params)

    is_name_changed = @template.name_changed?

    @template.save!

    SearchEntries.enqueue_reindex(@template) if is_name_changed

    WebhookUrls.enqueue_events(@template, 'template.updated')

    head :ok
  end

  def destroy
    notice =
      if params[:permanently].in?(['true', true])
        @template.destroy!

        I18n.t('template_has_been_removed')
      else
        @template.update!(archived_at: Time.current)

        WebhookUrls.enqueue_events(@template, 'template.archived')

        I18n.t('template_has_been_archived')
      end

    redirect_back(fallback_location: root_path, notice:)
  end

  private

  def assign_create_preferences(template)
    return if params.dig(:template, :preferences).blank?

    confidential_access = params.dig(:template, :preferences, :confidential_access)

    template.preferences = template.preferences.merge(
      'confidential_access' => confidential_access == 'true'
    )
  end

  def template_params
    params.require(:template).permit(
      :name,
      { schema: [[:attachment_uuid, :google_drive_file_id, :name, :dynamic,
                  { conditions: [%i[field_uuid value action operation]] }]],
        submitters: [%i[name uuid is_requester linked_to_uuid invite_via_field_uuid
                        invite_by_uuid optional_invite_by_uuid email order]],
        variables_schema: {},
        fields: [[:uuid, :submitter_uuid, :name, :type,
                  :required, :readonly, :default_value,
                  :title, :description, :prefillable,
                  { preferences: {},
                    default_value: [],
                    conditions: [%i[field_uuid value action operation]],
                    options: [%i[value uuid]],
                    validation: %i[message pattern min max step],
                    areas: [%i[uuid x y w h cell_w attachment_uuid option_uuid page]] }]] }
    )
  end
end
