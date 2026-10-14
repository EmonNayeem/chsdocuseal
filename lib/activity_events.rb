# frozen_string_literal: true

module ActivityEvents
  SUBMITTER_EVENT_ACTIONS = {
    'view_form' => 'submitter.viewed_form',
    'start_form' => 'submitter.started_form',
    'complete_form' => 'submitter.completed_form',
    'decline_form' => 'submitter.declined_form',
    'delegate_form' => 'submitter.delegated_form'
  }.freeze

  EMAIL_EVENT_ACTIONS = {
    invitation: 'submission.email_sent',
    reminder: 'submission.reminder_email_sent'
  }.freeze

  class << self
    def record!(actor:, action:, subject: nil, request: nil, metadata: {}, **overrides)
      account_id = overrides[:account_id] || subject.try(:account_id) || actor&.account_id
      actor_user_id = overrides.key?(:actor_user_id) ? overrides[:actor_user_id] : actor&.id

      actor_name, actor_email = resolve_actor_identity(actor, overrides)
      subject_type, subject_id, subject_label = resolve_subject_info(subject, overrides)
      company_id, visibility_scope = resolve_company_and_scope(subject, overrides)
      meta = build_metadata(metadata, request)
      occurred_at = overrides[:occurred_at] || Time.current

      ActivityEvent.create!(
        account_id:, company_id:, actor_user_id:, action:,
        subject_type:, subject_id:, subject_label:,
        actor_name:, actor_email:, visibility_scope:,
        metadata: meta, occurred_at:
      )
    end

    def record_submitter_event!(submitter:, event_type: nil, action: nil, submission_event: nil, request: nil)
      action ||= SUBMITTER_EVENT_ACTIONS[event_type.to_s]
      return if action.blank? || !SUBMITTER_EVENT_ACTIONS.value?(action) || submitter.blank?

      submission = submitter.try(:submission)
      return if submission.blank? || submitter_event_exists?(action, submission.id, submitter.id)

      record_submitter_activity!(submitter, submission, action, submission_event, request)
    end

    def record_submission_email!(submitter:, submission_event:, email_type:, metadata: {})
      action = EMAIL_EVENT_ACTIONS[email_type.to_sym]
      return if action.blank? || submitter.blank? || submission_event.blank?

      submission = submitter.try(:submission)
      return if submission.blank? || submission_email_event_exists?(action, submission.id, submission_event.id)

      record_email_activity!(submitter, submission, action, submission_event, metadata)
    end

    def recent_for(user, limit: 8)
      return ActivityEvent.none unless user&.admin_or_platform_admin?

      ActivityEvent.visible_to(user).newest_first.limit(limit)
    end

    private

    def resolve_actor_identity(actor, overrides)
      name = overrides[:actor_name] || actor&.full_name.presence || actor&.first_name.presence || actor&.email
      email = overrides[:actor_email] || actor&.email
      [name, email]
    end

    def resolve_subject_info(subject, overrides)
      type = overrides[:subject_type] || derive_subject_type(subject)
      id = overrides.key?(:subject_id) ? overrides[:subject_id] : subject.try(:id)
      label = overrides[:subject_label] || derive_subject_label(subject)
      [type, id, label]
    end

    def build_metadata(metadata, request)
      meta = (metadata || {}).stringify_keys
      if request.present?
        meta['ip'] ||= request.remote_ip if request.respond_to?(:remote_ip)
        meta['user_agent'] ||= request.user_agent if request.respond_to?(:user_agent)
      end
      meta
    end

    def derive_subject_type(subject)
      return 'Unknown' if subject.nil?
      return subject.name if subject.is_a?(Class)

      subject.class.base_class.name
    end

    def derive_subject_label(subject)
      return 'Unknown' if subject.nil?

      case subject
      when RecipientContact
        subject.name.present? ? "#{subject.name} <#{subject.email}>" : subject.email.to_s
      when Template
        subject.name.to_s
      when Submission
        derive_submission_label(subject)
      else
        derive_fallback_label(subject)
      end
    end

    def derive_submission_label(subject)
      template_name = subject.template&.name.presence || subject.name.presence || 'Submission'
      "#{template_name} ##{subject.id}"
    end

    def derive_fallback_label(subject)
      if subject.respond_to?(:name) && subject.name.present?
        subject.name.to_s
      elsif subject.respond_to?(:title) && subject.title.present?
        subject.title.to_s
      else
        "#{derive_subject_type(subject)} ##{subject.try(:id)}"
      end
    end

    def resolve_company_and_scope(subject, overrides)
      if overrides.key?(:visibility_scope)
        company_id = overrides.key?(:company_id) ? overrides[:company_id] : subject.try(:company_id)
        return [company_id, overrides[:visibility_scope]]
      end

      if overrides.key?(:company_id)
        company_id = overrides[:company_id]
        scope = company_id.present? ? 'company' : 'account'
        return [company_id, scope]
      end

      if subject.is_a?(RecipientContact)
        subject.company_id.present? ? [subject.company_id, 'company'] : [nil, 'account']
      elsif subject.respond_to?(:company_id) && subject.company_id.present?
        [subject.company_id, 'company']
      else
        [nil, 'account']
      end
    end

    def submitter_event_exists?(action, submission_id, submitter_id)
      ActivityEvent.where(
        action:,
        subject_type: 'Submission',
        subject_id: submission_id
      ).any? { |ae| ae.metadata['submitter_id'].to_s == submitter_id.to_s }
    end

    def record_submitter_activity!(submitter, submission, action, submission_event, request)
      company_id = submission.company_id
      record!(
        actor: nil,
        actor_user_id: nil,
        actor_name: submitter.name.presence || submitter.email.presence || 'Recipient',
        actor_email: submitter.email.presence,
        action:,
        subject: submission,
        account_id: submission.account_id,
        company_id:,
        visibility_scope: company_id.present? ? 'company' : 'account',
        request:,
        metadata: {
          'submitter_id' => submitter.id,
          'submitter_uuid' => submitter.uuid,
          'submitter_role' => (submitter.respond_to?(:role) ? submitter.role.presence : nil),
          'submission_event_id' => submission_event&.id
        }.compact
      )
    end

    def submission_email_event_exists?(action, submission_id, submission_event_id)
      ActivityEvent.where(
        action:,
        subject_type: 'Submission',
        subject_id: submission_id
      ).any? { |ae| ae.metadata['submission_event_id'].to_s == submission_event_id.to_s }
    end

    def record_email_activity!(submitter, submission, action, submission_event, metadata)
      company_id = submission.company_id.presence || submitter.try(:company_id).presence
      account_id = submission.account_id.presence || submitter.try(:account_id).presence
      record!(
        actor: nil,
        actor_user_id: nil,
        actor_name: 'System',
        actor_email: nil,
        action:,
        subject: submission,
        account_id:,
        company_id:,
        visibility_scope: company_id.present? ? 'company' : 'account',
        metadata: build_email_metadata(submitter, submission_event, metadata)
      )
    end

    def build_email_metadata(submitter, submission_event, metadata)
      meta = {
        'submitter_id' => submitter.id,
        'submitter_uuid' => submitter.uuid,
        'recipient_name' => submitter.name.presence,
        'recipient_email' => submitter.email.presence,
        'submission_event_id' => submission_event.id
      }
      if metadata.present?
        meta['slot'] = (metadata['slot'] || metadata[:slot]).presence
        meta['duration'] = (metadata['duration'] || metadata[:duration]).presence
      end
      meta.compact
    end
  end
end
