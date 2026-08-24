class AddSecondaryAndAccentColorsToCompanies < ActiveRecord::Migration[7.0]
  def change
    add_column :companies, :brand_secondary_color, :string
    add_column :companies, :brand_accent_color, :string
  end
end
