# frozen_string_literal: true

class AddBrandingToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :branding_enabled, :boolean, default: false, null: false
    add_column :companies, :brand_name, :string
    add_column :companies, :brand_from_email_name, :string
    add_column :companies, :brand_primary_color, :string
    add_column :companies, :brand_logo_key, :string
    add_column :companies, :brand_icon_key, :string
  end
end
