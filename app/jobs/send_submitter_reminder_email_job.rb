# frozen_string_literal: true

class SendSubmitterReminderEmailJob
  include Sidekiq::Job

  STALE_THRESHOLD = 15.minutes
  VALID_SLOTS = %w[first_duration second_duration third_duration].freeze

  def perform(params = {})
    submitter = Submitter.find_by(id: params['submitter_id'])
    return unless submitter

    slot = params['slot']
    return unless VALID_SLOTS.include?(slot)

    due_at = SubmitterReminders::Due.due_at(submitter, slot)
    return unless due_at && reminder_ready?(submitter, slot)

    claim = acquire_claim(submitter, slot, due_at)
    return unless claim

    deliver_reminder(submitter, claim)
    mark_sent(claim)
    record_submission_event(submitter, slot, claim.duration_key)
  end

  private

  def reminder_ready?(submitter, slot)
    SubmitterReminders::Due.due?(submitter, slot) && SubmitterReminders::Due.eligible?(submitter)
  end

  def acquire_claim(submitter, slot, due_at)
    duration_key = SubmitterReminders::Due.duration_key_for_slot(submitter.account, slot) || ''
    claim = SubmitterReminderDelivery.find_or_initialize_by(
      submitter_id: submitter.id,
      slot: slot
    )

    if claim.new_record?
      create_claim(claim, submitter, duration_key, due_at)
    else
      claim_existing_delivery(claim)
    end
  end

  def create_claim(claim, submitter, duration_key, due_at)
    claim.account_id = submitter.account_id
    claim.company_id = submitter.company_id
    claim.duration_key = duration_key
    claim.due_at = due_at
    claim.status = 'pending'

    claim.save!
    claim
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def claim_existing_delivery(claim)
    case claim.status
    when 'sent'
      nil
    when 'failed'
      claim_failed_delivery(claim)
    when 'pending'
      claim_pending_delivery(claim)
    end
  end

  def claim_failed_delivery(claim)
    updated_rows = SubmitterReminderDelivery
                   .where(id: claim.id, status: 'failed')
                   .update_all(status: 'pending', updated_at: Time.current)
    return nil unless updated_rows == 1

    claim.reload
  end

  def claim_pending_delivery(claim)
    return nil if claim.updated_at > STALE_THRESHOLD.ago

    updated_rows = SubmitterReminderDelivery
                   .where(id: claim.id, status: 'pending', updated_at: claim.updated_at)
                   .update_all(updated_at: Time.current)
    return nil unless updated_rows == 1

    claim.reload
  end

  def deliver_reminder(submitter, claim)
    mail = SubmitterMailer.reminder_email(submitter)
    Submitters::ValidateSending.call(submitter, mail)
    mail.deliver_now!
  rescue StandardError => e
    claim.update!(status: 'failed') unless claim.status == 'sent'
    raise e
  end

  def mark_sent(claim)
    claim.update!(status: 'sent', sent_at: Time.current)
  end

  def record_submission_event(submitter, slot, duration_key)
    SubmissionEvent.create!(
      submitter: submitter,
      event_type: 'send_reminder_email',
      data: {
        'slot' => slot,
        'duration' => duration_key
      }
    )
  rescue StandardError => e
    if defined?(Rollbar)
      Rollbar.error(e, 'Failed to create send_reminder_email SubmissionEvent', submitter_id: submitter.id)
    else
      Rails.logger.error("Failed to create send_reminder_email SubmissionEvent: #{e.message}")
    end
  end
end
