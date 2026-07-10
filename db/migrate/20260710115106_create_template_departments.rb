# frozen_string_literal: true

class CreateTemplateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :template_departments do |t|
      t.references :template,
                   null: false,
                   index: false,
                   foreign_key: { on_delete: :cascade }

      t.references :department,
                   null: false,
                   index: false,
                   foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :template_departments,
              %i[template_id department_id],
              unique: true,
              name: 'index_template_departments_on_template_id_and_department_id'

    add_index :template_departments,
              %i[department_id template_id],
              name: 'index_template_departments_on_department_id_and_template_id'
  end
end