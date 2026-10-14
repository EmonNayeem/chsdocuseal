# frozen_string_literal: true

class ActivityEvent < ApplicationRecord
  VISIBILITY_SCOPES = %w[company account].freeze

  belongs_to :account
  belongs_to :company, optional: true
  belongs_to :actor_user, class_name: 'User', optional: true

  attribute :metadata, default: -> { {} }
  serialize :metadata, coder: JSON

  validates :action, presence: true
  validates :subject_type, presence: true
  validates :subject_label, presence: true
  validates :visibility_scope, presence: true, inclusion: { in: VISIBILITY_SCOPES }
  validates :occurred_at, presence: true
  validates :company_id, presence: true, if: -> { visibility_scope == 'company' }

  validate :company_belongs_to_account
  validate :actor_belongs_to_account

  scope :newest_first, -> { order(occurred_at: :desc, id: :desc) }

  scope :visible_to, lambda { |user|
    return none if user.blank?

    if user.platform_admin?
      where(account_id: user.account_id)
    elsif user.department_acl_admin?
      where(account_id: user.account_id)
        .where(
          "(visibility_scope = 'account') OR (visibility_scope = 'company' AND company_id = :company_id)",
          company_id: user.company_id
        )
    else
      none
    end
  }

  scope :by_action, ->(action) { where(action: action) if action.present? }
  scope :by_actor, lambda { |actor_param|
    return all if actor_param.blank?

    param_str = actor_param.to_s.strip
    if param_str.start_with?('email:')
      email = param_str.sub(/^email:/, '').strip.downcase
      where(actor_user_id: nil).where('LOWER(actor_email) = ?', email)
    elsif param_str.start_with?('name:')
      name = param_str.sub(/^name:/, '').strip
      where(actor_user_id: nil, actor_name: name)
    else
      user_id = param_str.sub(/^user:/, '').strip
      where(actor_user_id: user_id)
    end
  }
  scope :by_company, ->(comp_id) { where(company_id: comp_id) if comp_id.present? }
  scope :from_date, lambda { |date|
    where(occurred_at: date.beginning_of_day..) if date.present?
  }
  scope :to_date, lambda { |date|
    where(occurred_at: ..date.end_of_day) if date.present?
  }

  def actor_display_name
    actor_name.presence || actor_email.presence || 'System'
  end

  def actor_display_email
    actor_email
  end

  private

  def company_belongs_to_account
    return if company_id.blank? || account_id.blank?

    target_account_id = company ? company.account_id : Company.where(id: company_id).pick(:account_id)
    return if target_account_id == account_id

    errors.add(:company_id, :invalid, message: 'must belong to the same account')
  end

  def actor_belongs_to_account
    return if actor_user_id.blank? || account_id.blank?

    target_account_id = actor_user ? actor_user.account_id : User.where(id: actor_user_id).pick(:account_id)
    return if target_account_id == account_id

    errors.add(:actor_user_id, :invalid, message: 'must belong to the same account')
  end
end
