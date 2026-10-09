# frozen_string_literal: true

class RecipientContactsController < ApplicationController
  skip_authorization_check
  before_action :authorize_recipient_management!
  before_action :set_recipient_contact, only: %i[edit update destroy]

  def index
    @recipient_contacts = recipient_contacts_scope.order(:name).preload(:company)
  end

  def new
    @recipient_contact = current_account.recipient_contacts.new
    @recipient_contact.company = current_user.company unless current_user.platform_admin?
    load_companies
  end

  def edit
    load_companies
  end

  def create
    @recipient_contact = current_account.recipient_contacts.new(recipient_contact_params)
    @recipient_contact.company = current_user.company unless current_user.platform_admin?

    if @recipient_contact.save
      redirect_to settings_recipient_contacts_path, notice: 'Recipient contact has been created.'
    else
      load_companies
      render :new, status: :unprocessable_content
    end
  end

  def update
    assign_params = recipient_contact_params
    assign_params[:company_id] = current_user.company_id unless current_user.platform_admin?

    if @recipient_contact.update(assign_params)
      redirect_to settings_recipient_contacts_path, notice: 'Recipient contact has been updated.'
    else
      load_companies
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @recipient_contact.destroy!
    redirect_to settings_recipient_contacts_path, notice: 'Recipient contact has been deleted.'
  end

  private

  def load_companies
    return unless current_user.platform_admin?

    @companies = current_account.companies.where(active: true)

    if @recipient_contact&.company_id.present?
      existing_company = current_account.companies.where(id: @recipient_contact.company_id)
      @companies = @companies.or(existing_company)
    end

    @companies = @companies.order(:name)
    @companies = current_account.companies.order(:name) if @companies.empty?
  end

  def recipient_contacts_scope
    current_account.recipient_contacts.visible_to(current_user)
  end

  def authorize_recipient_management!
    raise CanCan::AccessDenied unless current_user.platform_admin? || current_user.department_acl_admin?
  end

  def set_recipient_contact
    @recipient_contact = current_account.recipient_contacts.visible_to(current_user).find(params[:id])
    # If a company admin tries to edit/destroy a Shared contact, they should be blocked.
    # We can rely on CanCanCan for this.
    authorize! action_name.to_sym, @recipient_contact
  end

  def recipient_contact_params
    if current_user.platform_admin?
      params.require(:recipient_contact).permit(:name, :email, :phone, :company_id)
    else
      params.require(:recipient_contact).permit(:name, :email, :phone)
    end
  end
end
