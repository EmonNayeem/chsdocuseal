# frozen_string_literal: true

class BackfillSubmitterRemindersEnabledAt < ActiveRecord::Migration[7.0]
  class MigrationAccountConfig < ActiveRecord::Base
    self.table_name = 'account_configs'
    serialize :value, coder: JSON
  end

  def up
    cutoff_time = Time.current.utc.iso8601
    valid_keys = %w[
      one_hour two_hours four_hours eight_hours twelve_hours
      twenty_four_hours two_days three_days four_days five_days
      six_days seven_days eight_days fifteen_days twenty_one_days thirty_days
    ]

    MigrationAccountConfig.where(key: 'submitter_reminders').find_each do |config|
      val = config.value || {}

      is_enabled = %w[first_duration second_duration third_duration].any? do |slot|
        valid_keys.include?(val[slot].to_s)
      end

      next unless is_enabled
      next if val['enabled_at'].present?

      val['enabled_at'] = cutoff_time
      config.update_column(:value, val)
    end
  end

  def down
    MigrationAccountConfig.where(key: 'submitter_reminders').find_each do |config|
      val = config.value || {}

      if val.key?('enabled_at')
        val.delete('enabled_at')
        config.update_column(:value, val)
      end
    end
  end
end
