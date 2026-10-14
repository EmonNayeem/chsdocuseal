# frozen_string_literal: true

class SendSubmitterInvitationEmailJob
  include Sidekiq::Job

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])

    return if submitter.completed_at?
    return if submitter.declined_at?
    return if submitter.submission.archived_at?
    return if submitter.submission.expired?
    return if submitter.template&.archived_at?
    return if submitter.submission.source == 'invite' && !Accounts.can_send_emails?(submitter.account, on_events: true)

    unless Accounts.can_send_invitation_emails?(submitter.account)
      Rollbar.warning("Skip email: #{submitter.account.id}") if defined?(Rollbar)

      return
    end

    mail =
      if submitter.viewer?
        SubmitterMailer.invitation_view_email(submitter)
      else
        SubmitterMailer.invitation_email(submitter)
      end

    Submitters::ValidateSending.call(submitter, mail)

    mail.deliver_now!

    submission_event = SubmissionEvent.create!(submitter:, event_type: 'send_email')

    record_activity_event(submitter, submission_event)

    submitter.sent_at ||= Time.current
    submitter.save!
  end

  private

  def record_activity_event(submitter, submission_event)
    ActivityEvents.record_submission_email!(
      submitter:,
      submission_event:,
      email_type: :invitation
    )
  rescue StandardError => e
    if defined?(Rollbar)
      Rollbar.error(
        e,
        'Failed to create submission.email_sent ActivityEvent',
        submitter_id: submitter.id,
        submission_event_id: submission_event.id
      )
    else
      Rails.logger.error("Failed to create submission.email_sent ActivityEvent: #{e.message}")
    end
  end
end
