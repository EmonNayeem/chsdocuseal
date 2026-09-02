# frozen_string_literal: true

class TemplatesCopyController < ApplicationController
  load_and_authorize_resource :template, instance_name: :base_template

  def new
    authorize!(:read, @base_template)

    unless can_copy_template?
      redirect_back(fallback_location: root_path, alert: 'You are not allowed to copy this template.')
      return
    end

    setup_target_company_variables

    @template = Template.new(name: "#{@base_template.name} (#{I18n.t('copy', default: 'Copy')})")
  end

  def create
    authorize!(:read, @base_template)

    unless can_copy_template?
      redirect_back(fallback_location: root_path, alert: 'You are not allowed to copy this template.')
      return
    end

    setup_target_company_variables

    begin
      @template = Templates::CopyTemplate.call(
        template: @base_template,
        target_company: @target_company,
        current_user: current_user,
        target_department_ids: params[:department_ids],
        target_folder_id: params[:folder_id],
        name: params.dig(:template, :name)
      )

      redirect_to(edit_template_path(@template),
                  notice: I18n.t('template_copied_successfully', default: 'Template copied successfully.'))
    rescue Templates::CopyTemplate::UnauthorizedError, Templates::CopyTemplate::InvalidTargetError => e
      flash.now[:alert] = e.message
      @template = Template.new(name: params.dig(:template, :name))
      setup_target_company_variables
      render turbo_stream: turbo_stream.replace(:modal, partial: 'templates_copy/form'), status: :unprocessable_content
    rescue StandardError => e
      flash.now[:alert] = "Failed to copy template: #{e.message}"
      @template = Template.new(name: params.dig(:template, :name))
      setup_target_company_variables
      render turbo_stream: turbo_stream.replace(:modal, partial: 'templates_copy/form'), status: :unprocessable_content
    end
  end

  private

  def can_copy_template?
    return true if current_user.platform_admin?
    return true if current_user.department_acl_admin? && @base_template.company_id == current_user.company_id

    false
  end

  def setup_target_company_variables
    company_id_param = params[:target_company_id] || params[:company_id]

    if current_user.platform_admin?
      @target_company = if company_id_param.present?
                          Company.find_by(id: company_id_param) || @base_template.company || current_user.company
                        else
                          @base_template.company || current_user.company
                        end
      @target_departments = Department.where(company: @target_company).order(:name)
      @target_folders = TemplateFolder.where(company: @target_company).order(:name)
      @default_folder_id = if @target_company == @base_template.company
                             @base_template.folder_id
                           elsif (account = @target_company&.account)
                             account.default_template_folder&.id
                           end

      prepare_platform_admin_json_data
    else
      @target_company = current_user.company
    end
  end

  def prepare_platform_admin_json_data
    @all_departments_json = Department.select(:id, :name, :company_id).order(:name).to_json
    @all_folders_json = TemplateFolder.select(:id, :name, :company_id).order(:name).to_json
    @companies_default_folders_json = Company.includes(:account).to_h do |company|
      [company.id, company.account&.default_template_folder&.id]
    end.to_json
  end
end
