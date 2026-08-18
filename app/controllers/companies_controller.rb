# frozen_string_literal: true

class CompaniesController < ApplicationController
  skip_authorization_check
  before_action :authorize_platform_admin!
  before_action :set_company, only: %i[edit update]

  def index
    @companies = current_account.companies.order(:name)
  end

  def edit; end

  def update
    if @company.update(company_params)
      redirect_to settings_companies_path, notice: 'Company settings updated successfully.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def authorize_platform_admin!
    redirect_to root_path, alert: I18n.t('access_denied', default: 'Access denied.') unless current_user.platform_admin?
  end

  def set_company
    @company = current_account.companies.find(params[:id])
  end

  def company_params
    p = params.require(:company).permit(
      :active, :smtp_enabled, :smtp_address, :smtp_port, :smtp_domain,
      :smtp_user_name, :smtp_password, :smtp_authentication,
      :smtp_enable_starttls_auto, :smtp_from_email, :smtp_from_name,
      :branding_enabled, :brand_name, :brand_from_email_name,
      :brand_primary_color, :brand_logo_key, :brand_icon_key
    )
    p.delete(:smtp_password) if p[:smtp_password].blank?
    p
  end
end
