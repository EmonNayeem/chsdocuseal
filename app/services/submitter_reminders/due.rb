# frozen_string_literal: true

module SubmitterReminders
  module Due
    module_function

    def config_for(account)
      AccountConfigs.find_for_account(account, AccountConfig::SUBMITTER_REMINDERS)&.value || {}
    end

    def duration_key_for_slot(account, slot)
      config_for(account)[slot]
    end

    def time_duration_for_slot(account, slot)
      key = duration_key_for_slot(account, slot)
      return nil if key.blank?

      duration_str = AccountConfigs::REMINDER_DURATIONS[key]
      return nil unless duration_str

      amount, unit = duration_str.split
      amount.to_i.send(unit)
    end

    def due_at(submitter, slot)
      duration = time_duration_for_slot(submitter.account, slot)
      return nil unless duration && submitter.sent_at

      submitter.sent_at + duration
    end

    def due?(submitter, slot, time = Time.current)
      due_time = due_at(submitter, slot)
      return false unless due_time

      time >= due_time
    end

    def eligible?(submitter)
      basic_submitter_eligible?(submitter) &&
        submission_eligible?(submitter.submission) &&
        template_eligible?(submitter) &&
        delivery_preferences_eligible?(submitter) &&
        account_eligible?(submitter)
    end

    def basic_submitter_eligible?(submitter)
      submitter.email.present? &&
        submitter.sent_at.present? &&
        !submitter.completed_at? &&
        !submitter.declined_at?
    end

    def submission_eligible?(submission)
      !submission.archived_at? && !submission.expired?
    end

    def template_eligible?(submitter)
      template = submitter.template || submitter.submission.template
      !template&.archived_at?
    end

    def delivery_preferences_eligible?(submitter)
      !submitter.viewer? && submitter.preferences['send_email'] != false
    end

    def account_eligible?(submitter)
      return false unless Submitters.current_submitter_order?(submitter)

      submission = submitter.submission
      return false if submission.source == 'invite' && !Accounts.can_send_emails?(submitter.account, on_events: true)

      Accounts.can_send_invitation_emails?(submitter.account)
    end
  end
end
