# frozen_string_literal: true

class TemplatesCopyController < ApplicationController
  load_and_authorize_resource :template, instance_name: :base_template

  def new
    authorize!(:read, @base_template)

    unless can_copy_template?
      redirect_back(fallback_location: root_path, alert: 'You are not allowed to copy this template.')
      return
    end

    @template = Template.new(name: "#{@base_template.name} (#{I18n.t('copy', default: 'Copy')})")
  end

  def create
    authorize!(:read, @base_template)

    unless can_copy_template?
      redirect_back(fallback_location: root_path, alert: 'You are not allowed to copy this template.')
      return
    end

    begin
      @template = Templates::CopyTemplate.call(
        template: @base_template,
        target_company: determine_target_company,
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
      render turbo_stream: turbo_stream.replace(:modal, partial: 'templates_copy/form'), status: :unprocessable_content
    rescue StandardError => e
      flash.now[:alert] = "Failed to copy template: #{e.message}"
      @template = Template.new(name: params.dig(:template, :name))
      render turbo_stream: turbo_stream.replace(:modal, partial: 'templates_copy/form'), status: :unprocessable_content
    end
  end

  private

  def can_copy_template?
    return true if current_user.platform_admin?
    return true if current_user.department_acl_admin? && @base_template.company_id == current_user.company_id

    false
  end

  def determine_target_company
    if current_user.platform_admin? && params[:company_id].present?
      Company.find_by(id: params[:company_id])
    else
      current_user.company
    end
  end
end
