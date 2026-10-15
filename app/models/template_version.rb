# frozen_string_literal: true

# == Schema Information
#
# Table name: template_versions
#
#  id          :bigint           not null, primary key
#  data        :text             not null
#  sha1        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  author_id   :bigint           not null
#  company_id  :bigint           not null
#  template_id :bigint           not null
#
# Indexes
#
#  index_template_versions_on_account_id            (account_id)
#  index_template_versions_on_author_id             (author_id)
#  index_template_versions_on_company_id            (company_id)
#  index_template_versions_on_template_id_and_sha1  (template_id,sha1) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (author_id => users.id)
#  fk_rails_...  (company_id => companies.id)
#  fk_rails_...  (template_id => templates.id)
class TemplateVersion < ApplicationRecord
  has_many_attached :documents
  has_many_attached :dynamic_attachments

  before_validation :assign_company_from_parent, on: :create
  before_validation :set_account, on: :create

  belongs_to :template
  belongs_to :account
  belongs_to :company
  belongs_to :author, class_name: 'User'

  attribute :data, :string, default: -> { {} }

  serialize :data, coder: JSON

  validate :matches_template_tenancy

  def schema
    Array.wrap(data['schema'])
  end

  def schema_documents
    documents_attachments.where(uuid: schema.pluck('attachment_uuid'))
  end

  def version_number
    @version_number ||= template.template_versions.where(id: ..id).count
  end

  private

  def set_account
    self.account ||= template&.account
  end

  def assign_company_from_parent
    self.company_id ||= template&.company_id
  end

  def matches_template_tenancy
    return unless template

    errors.add(:account_id, 'must match template account') if account_id.present? && account_id != template.account_id
    errors.add(:company_id, 'must match template company') if company_id.present? && company_id != template.company_id
  end
end
