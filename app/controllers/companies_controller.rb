# frozen_string_literal: true

class CompaniesController < ApplicationController
  skip_authorization_check
  before_action :authorize_platform_admin!

  def index
    @companies = current_account.companies.order(:name)
  end

  private

  def authorize_platform_admin!
    redirect_to root_path, alert: I18n.t('access_denied', default: 'Access denied.') unless current_user.platform_admin?
  end
end
