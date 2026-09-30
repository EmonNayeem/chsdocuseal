# frozen_string_literal: true

class ScanSubmitterRemindersJob
  include Sidekiq::Job

  sidekiq_options queue: 'recurrent'

  SCAN_INTERVAL = 15.minutes

  def perform(params = {})
    token = params['scheduler_token']
    return if token.blank?
    return unless SubmitterReminders::ScannerLease.verify_or_acquire!(token)

    candidates = Submitter.where.not(sent_at: nil)
                          .where(completed_at: nil, declined_at: nil)
                          .where.not(email: [nil, ''])

    candidates.find_each do |submitter|
      slot = SubmitterReminders::NextDueSlot.call(submitter)
      next unless slot

      SendSubmitterReminderEmailJob.perform_async(
        'submitter_id' => submitter.id,
        'slot' => slot
      )
    end

    return unless SubmitterReminders::ScannerLease.verify_or_acquire!(token)

    self.class.perform_in(SCAN_INTERVAL, 'scheduler_token' => token)
  end
end
