# frozen_string_literal: true

module SubmitterReminders
  module NextDueSlot
    module_function

    SLOTS = %w[first_duration second_duration third_duration].freeze
    REMINDER_COOLDOWN = 24.hours

    def call(submitter)
      return nil unless SubmitterReminders::Due.eligible?(submitter)

      last_sent = SubmitterReminderDelivery.where(submitter_id: submitter.id, status: 'sent')
                                           .order(sent_at: :desc)
                                           .first

      return nil if last_sent&.sent_at && last_sent.sent_at > REMINDER_COOLDOWN.ago

      SLOTS.each do |slot|
        duration = SubmitterReminders::Due.time_duration_for_slot(submitter.account, slot)
        next unless duration

        delivery = SubmitterReminderDelivery.find_by(submitter_id: submitter.id, slot: slot)

        next if delivery&.status == 'sent'

        return nil unless SubmitterReminders::Due.due?(submitter, slot)

        return slot if delivery.nil?
        return slot if delivery.status == 'failed'

        if delivery.status == 'pending'
          stale_threshold = SendSubmitterReminderEmailJob::STALE_THRESHOLD.ago
          return delivery.updated_at <= stale_threshold ? slot : nil
        end
      end

      nil
    end
  end
end
