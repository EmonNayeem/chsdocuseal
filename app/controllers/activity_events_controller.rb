# frozen_string_literal: true

class ActivityEventsController < ApplicationController
  AVAILABLE_ACTIONS = [
    ['Created recipient', 'recipient_contact.created'],
    ['Updated recipient', 'recipient_contact.updated'],
    ['Deleted recipient', 'recipient_contact.deleted'],
    ['Created template', 'template.created'],
    ['Updated template', 'template.updated'],
    ['Restored template version', 'template.version_restored'],
    ['Archived template', 'template.archived'],
    ['Deleted template', 'template.deleted'],
    ['Created submission', 'submission.created'],
    ['Archived submission', 'submission.archived'],
    ['Deleted submission', 'submission.deleted'],
    ['Sent signature request email', 'submission.email_sent'],
    ['Sent reminder email', 'submission.reminder_email_sent'],
    ['Viewed submission', 'submitter.viewed_form'],
    ['Started submission', 'submitter.started_form'],
    ['Completed submission', 'submitter.completed_form'],
    ['Declined submission', 'submitter.declined_form'],
    ['Delegated submission', 'submitter.delegated_form']
  ].freeze

  skip_authorization_check
  before_action :authorize_activity_log_access!

  def index
    normalize_actor_param!
    authorized_scope = current_account.activity_events.visible_to(current_user)
    scope = filter_activity_events(authorized_scope.newest_first)

    @pagy, @activity_events = pagy(scope.preload(:company, :actor_user), limit: 25)
    @actors = available_actors_for(authorized_scope)
    @companies = current_account.companies.order(:name) if current_user.platform_admin?
    @available_actions = AVAILABLE_ACTIONS
  end

  private

  def normalize_actor_param!
    return if params[:actor_id].blank?

    val = params[:actor_id].to_s.strip
    params[:actor_id] = "user:#{val}" if val.match?(/\A\d+\z/)
  end

  def filter_activity_events(scope)
    scope = scope.by_action(params[:action_name]) if params[:action_name].present?
    scope = scope.by_actor(params[:actor_id]) if params[:actor_id].present?
    scope = scope.by_company(params[:company_id]) if current_user.platform_admin? && params[:company_id].present?
    scope = scope.from_date(parse_date_param(params[:from_date])) if params[:from_date].present?
    scope = scope.to_date(parse_date_param(params[:to_date])) if params[:to_date].present?
    scope
  end

  def available_actors_for(scope)
    rows = scope.pluck(:actor_user_id, :actor_name, :actor_email)

    actors_map = {}

    rows.each do |user_id, name, email|
      if user_id.present?
        key = "user:#{user_id}"
        label = name.presence || email.presence || "User ##{user_id}"
        actors_map[key] ||= label
      elsif email.present?
        normalized_email = email.to_s.strip.downcase
        key = "email:#{normalized_email}"
        label = name.presence || email.to_s.strip
        actors_map[key] ||= label
      elsif name.present?
        trimmed_name = name.to_s.strip
        key = "name:#{trimmed_name}"
        label = trimmed_name
        actors_map[key] ||= label
      end
    end

    actors_map.map { |key, label| [label, key] }.sort_by { |label, _key| label.downcase }
  end

  def authorize_activity_log_access!
    raise CanCan::AccessDenied unless current_user&.platform_admin? || current_user&.department_acl_admin?
  end

  def parse_date_param(val)
    Date.parse(val.to_s)
  rescue ArgumentError
    nil
  end
end
