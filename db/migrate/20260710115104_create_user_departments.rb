# frozen_string_literal: true

class CreateUserDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_departments do |t|
      t.references :user,
                   null: false,
                   index: false,
                   foreign_key: { on_delete: :cascade }

      t.references :department,
                   null: false,
                   index: false,
                   foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :user_departments,
              %i[user_id department_id],
              unique: true,
              name: 'index_user_departments_on_user_id_and_department_id'

    add_index :user_departments,
              %i[department_id user_id],
              name: 'index_user_departments_on_department_id_and_user_id'
  end
end
