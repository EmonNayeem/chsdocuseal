# frozen_string_literal: true

class CreateActivityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, null: true, foreign_key: { on_delete: :nullify }
      t.references :actor_user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id
      t.string :subject_label, null: false

      t.string :actor_name
      t.string :actor_email

      t.string :visibility_scope, null: false
      t.text :metadata, null: false, default: '{}'
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :activity_events, %i[account_id occurred_at]
    add_index :activity_events, %i[company_id occurred_at]
    add_index :activity_events, %i[subject_type subject_id]
    add_index :activity_events, %i[action occurred_at]
  end
end
