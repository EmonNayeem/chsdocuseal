# frozen_string_literal: true

class CreateSubmitterReminderDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :submitter_reminder_deliveries do |t|
      t.references :submitter, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :slot, null: false
      t.string :duration_key, null: false
      t.datetime :due_at, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :sent_at

      t.timestamps
    end
    add_index :submitter_reminder_deliveries, %i[submitter_id slot], unique: true
  end
end
