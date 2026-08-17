# frozen_string_literal: true

class TemplatesDepartmentsController < ApplicationController
  load_and_authorize_resource :template

  def update
    authorize! :update, @template

    department_ids = allowed_template_department_ids(params.dig(:template, :department_ids))

    @template.department_ids = department_ids
    @template.save!

    redirect_back fallback_location: template_path(@template), notice: 'Template departments have been updated.'
  end

  private

  def allowed_template_department_ids(raw_ids)
    submitted_ids = Array(raw_ids).compact_blank

    if current_user.department_acl_admin?
      current_account.departments.where(id: submitted_ids).pluck(:id)
    else
      current_user.departments.where(id: submitted_ids).pluck(:id)
    end
  end
end
