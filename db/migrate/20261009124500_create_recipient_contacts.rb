# frozen_string_literal: true

class CreateRecipientContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :recipient_contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :company, null: true, foreign_key: true
      t.string :name
      t.string :email, null: false
      t.string :phone

      t.timestamps
    end

    add_index :recipient_contacts, %i[account_id email], unique: true
  end
end
