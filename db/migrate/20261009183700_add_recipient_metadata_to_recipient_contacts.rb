# frozen_string_literal: true

class AddRecipientMetadataToRecipientContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :recipient_contacts, :job_title, :string
    add_column :recipient_contacts, :department, :string
  end
end
