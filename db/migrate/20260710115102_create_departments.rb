# frozen_string_literal: true

class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :departments,
              %i[account_id name],
              unique: true,
              name: 'index_departments_on_account_id_and_name'
  end
end