# frozen_string_literal: true

class TemplateFoldersController < ApplicationController
  load_and_authorize_resource :template_folder

  helper_method :selected_order

  TEMPLATES_PER_PAGE = 12
  FOLDERS_PER_PAGE = 18

  def show
    @templates = Template.active.accessible_by(current_ability)
                         .where(folder: [@template_folder, *(params[:q].present? ? @template_folder.subfolders : [])])
                         .preload(:author, :template_accesses)

    @template_folders = @template_folder.subfolders.accessible_by(current_ability).active

    @template_folders = TemplateFolders.search(@template_folders, params[:q])
    @template_folders = TemplateFolders.sort(@template_folders, current_user, selected_order)

    if @templates.exists?
      @templates = Templates.search(current_user, @templates, params[:q])
      @templates = Templates::Order.call(@templates, current_user, selected_order)

      limit =
        if @template_folders.size < 4
          TEMPLATES_PER_PAGE
        else
          (@template_folders.size < 7 ? 9 : 6)
        end

      @pagy, @templates = pagy_auto(@templates.select_for_list, limit:)

      if params[:q].present? && @templates.blank?
        @related_submissions_pagy, @related_submissions = load_related_submissions(@template_folder)
      end
    else
      @pagy, @template_folders = pagy(@template_folders, limit: FOLDERS_PER_PAGE)

      @templates = @templates.none
    end
  end

  def new; end

  def edit; end

  def create
    @template_folder.author = current_user
    @template_folder.account = current_account
    @template_folder.company_id = current_user.company_id unless current_user.platform_admin?

    if @template_folder.save
      redirect_to folder_path(@template_folder),
                  notice: I18n.t('folder_created', default: 'Folder created successfully.')
    else
      redirect_to templates_path, alert: @template_folder.errors.full_messages.to_sentence
    end
  end

  def update
    if @template_folder != current_account.default_template_folder &&
       @template_folder.update(template_folder_params)
      redirect_to folder_path(@template_folder), notice: I18n.t('folder_name_has_been_updated')
    else
      redirect_to folder_path(@template_folder), alert: I18n.t('unable_to_rename_folder')
    end
  end

  def destroy
    has_contents = @template_folder.templates.active.exists? || @template_folder.subfolders.active.exists?

    if has_contents && params[:destroy_contents].blank?
      redirect_to folder_path(@template_folder),
                  alert: I18n.t('folder_not_empty_confirmation',
                                default: 'Folder contains templates or subfolders. Please confirm to delete.')
    elsif @template_folder.default?
      redirect_to folder_path(@template_folder),
                  alert: I18n.t('cannot_delete_default_folder', default: 'Cannot delete default folder.')
    else
      parent_folder = @template_folder.parent_folder

      archive_folder_and_contents(@template_folder)

      redirect_to parent_folder ? folder_path(parent_folder) : templates_path,
                  notice: I18n.t('folder_deleted', default: 'Folder deleted successfully.')
    end
  end

  private

  def archive_folder_and_contents(folder)
    TemplateFolder.transaction do
      folder.update!(archived_at: Time.current)
      folder.templates.active.find_each do |template|
        template.update!(archived_at: Time.current)
        WebhookUrls.enqueue_events(template, 'template.archived')
      end
      folder.subfolders.active.find_each do |subfolder|
        archive_folder_and_contents(subfolder)
      end
    end
  end

  def selected_order
    @selected_order ||=
      if can?(:manage, :countless)
        'created_at'
      else
        cookies.permanent[:dashboard_templates_order].presence || 'created_at'
      end
  end

  def template_folder_params
    params.require(:template_folder).permit(:name, :parent_folder_id, :company_id)
  end

  def load_related_submissions(template_folder)
    templates_scope = current_account.templates.active
    templates_scope = templates_scope.where(company_id: current_user.company_id) unless current_user.platform_admin?

    related_submissions =
      Submission.accessible_by(current_ability)
                .where(archived_at: nil)
                .where(template_id: templates_scope
                                                   .where(folder: [template_folder, *template_folder.subfolders])
                                                   .select(:id))
                .preload(:template_accesses, :created_by_user,
                         template: :author,
                         submitters: :start_form_submission_events)

    related_submissions = Submissions.search(current_user, related_submissions, params[:q])
                                     .order(id: :desc)

    pagy_auto(related_submissions.select_for_list, limit: 5)
  end
end
