# frozen_string_literal: true

class AddSmtpSettingsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :smtp_enabled, :boolean, default: false, null: false
    add_column :companies, :smtp_address, :string
    add_column :companies, :smtp_port, :integer
    add_column :companies, :smtp_domain, :string
    add_column :companies, :smtp_user_name, :string
    add_column :companies, :smtp_password, :text
    add_column :companies, :smtp_authentication, :string
    add_column :companies, :smtp_enable_starttls_auto, :boolean, default: false, null: false
    add_column :companies, :smtp_from_email, :string
    add_column :companies, :smtp_from_name, :string
  end
end
