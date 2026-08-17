# frozen_string_literal: true

class AddCompanyTenancyPhase1A < ActiveRecord::Migration[8.1]
  class Account < ApplicationRecord; end
  class Company < ApplicationRecord; end
  class User < ApplicationRecord; end
  class Department < ApplicationRecord; end
  class Template < ApplicationRecord; end
  class Submission < ApplicationRecord; end
  class Submitter < ApplicationRecord; end
  class TemplateFolder < ApplicationRecord; end
  class TemplateVersion < ApplicationRecord; end
  class SubmissionEvent < ApplicationRecord; end

  # rubocop:disable Metrics/AbcSize -- Existing complex migration
  def up
    create_table :companies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :companies, %i[account_id code], unique: true
    add_index :companies, %i[account_id name], unique: true

    add_column :users, :platform_admin, :boolean, null: false, default: false

    # Add company_id references
    %i[users departments templates submissions submitters template_folders template_versions
       submission_events].each do |table|
      add_reference table, :company, foreign_key: true, null: true
    end

    # Reset column information
    Account.reset_column_information
    Company.reset_column_information
    User.reset_column_information
    Department.reset_column_information
    Template.reset_column_information
    Submission.reset_column_information
    Submitter.reset_column_information
    TemplateFolder.reset_column_information
    TemplateVersion.reset_column_information
    SubmissionEvent.reset_column_information

    # Backfill
    Account.find_each do |account|
      md = Company.find_or_create_by!(account_id: account.id, code: 'MD') do |c|
        c.name = 'Materials Direct'
        c.active = true
      end

      Company.find_or_create_by!(account_id: account.id, code: 'CHS') do |c|
        c.name = 'Churchfield Home Services'
        c.active = true
      end

      Company.find_or_create_by!(account_id: account.id, code: 'SL') do |c|
        c.name = 'Smart Lotto'
        c.active = true
      end

      Company.find_or_create_by!(account_id: account.id, code: 'ESS') do |c|
        c.name = 'Efficient Software Solutions'
        c.active = true
      end

      # Update all existing records for this account
      User.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      Department.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      Template.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      Submission.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      Submitter.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      TemplateFolder.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      TemplateVersion.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
      SubmissionEvent.where(account_id: account.id, company_id: nil).update_all(company_id: md.id)
    end

    # Enforce non-null for tables that currently enforce non-null account_id
    %i[users departments templates submissions submitters template_folders template_versions].each do |table|
      change_column_null table, :company_id, false
    end

    # Replace department name uniqueness scoped to account_id with company_id
    remove_index :departments, column: %i[account_id name], name: 'index_departments_on_account_id_and_name',
                               if_exists: true
    add_index :departments, %i[company_id name], unique: true, name: 'index_departments_on_company_id_and_name',
                                                 if_not_exists: true
  end
  # rubocop:enable Metrics/AbcSize

  def down
    remove_index :departments, column: %i[company_id name], name: 'index_departments_on_company_id_and_name',
                               if_exists: true
    add_index :departments, %i[account_id name], unique: true, name: 'index_departments_on_account_id_and_name',
                                                 if_not_exists: true

    %i[users departments templates submissions submitters template_folders template_versions
       submission_events].each do |table|
      remove_reference table, :company, foreign_key: true
    end

    remove_column :users, :platform_admin

    drop_table :companies
  end
end
