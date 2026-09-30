# frozen_string_literal: true

class ScanSubmitterRemindersJob
  include Sidekiq::Job

  sidekiq_options queue: 'recurrent'

  def perform
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
  end
end
