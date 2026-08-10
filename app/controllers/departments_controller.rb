# frozen_string_literal: true

class DepartmentsController < ApplicationController
  before_action :authorize_department_management!
  before_action :set_department, only: %i[edit update destroy]

  def index
    @departments = departments_scope.order(:name).preload(:users, :templates)
  end

  def new
    @department = current_account.departments.new
    @department.company = current_user.company
  end

  def edit; end

  def create
    @department = current_account.departments.new(department_params)
    @department.company = current_user.company

    if @department.save
      redirect_to settings_departments_path, notice: 'Department has been created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @department.update(department_params)
      redirect_to settings_departments_path, notice: 'Department has been updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @department.users.exists? || @department.templates.exists?
      redirect_to settings_departments_path,
                  alert: 'Remove this department from all users and templates before deleting it.'
    else
      @department.destroy!
      redirect_to settings_departments_path, notice: 'Department has been deleted.'
    end
  end

  private

  def departments_scope
    if current_user.platform_admin?
      current_account.departments
    else
      current_account.departments.where(company_id: current_user.company_id)
    end
  end

  def authorize_department_management!
    authorize! :manage, Department
  end

  def set_department
    @department = departments_scope.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name)
  end
end
