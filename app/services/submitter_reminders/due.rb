# frozen_string_literal: true

require 'time'

module SubmitterReminders
  module Due
    module_function

    def config_for(account)
      AccountConfigs.find_for_account(account, AccountConfig::SUBMITTER_REMINDERS)&.value || {}
    end

    def schedule_enabled?(config_hash)
      return false unless config_hash.is_a?(Hash)

      %w[first_duration second_duration third_duration].any? do |slot|
        AccountConfigs::REMINDER_DURATIONS.key?(config_hash[slot].to_s)
      end
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

    def rollout_eligible?(submitter)
      return false unless submitter.sent_at

      config = config_for(submitter.account)
      return false unless schedule_enabled?(config)

      enabled_at_str = config['enabled_at']
      return false if enabled_at_str.blank?

      enabled_at_time = Time.iso8601(enabled_at_str)
      submitter.sent_at >= enabled_at_time
    rescue ArgumentError, TypeError
      false
    end

    def eligible?(submitter)
      basic_submitter_eligible?(submitter) &&
        rollout_eligible?(submitter) &&
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
