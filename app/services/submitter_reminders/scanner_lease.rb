# frozen_string_literal: true

require 'securerandom'

module SubmitterReminders
  module ScannerLease
    module_function

    KEY = 'submitter_reminder_scanner_lease'
    TTL = 30.minutes.to_i

    def verify_or_acquire!(token)
      script = <<~LUA
        local current = redis.call('GET', KEYS[1])
        if current == ARGV[1] then
          redis.call('EXPIRE', KEYS[1], ARGV[2])
          return 1
        end
        if not current then
          redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2])
          return 1
        end
        return 0
      LUA

      acquired = false
      Sidekiq.redis do |conn|
        acquired = conn.call('EVAL', script, 1, KEY, token, TTL.to_s) == 1
      end

      acquired
    end

    def bootstrap!(config)
      return if Rails.env.test?

      return if @bootstrapped

      @bootstrapped = true

      config.on(:startup) do
        token = SecureRandom.uuid
        ScanSubmitterRemindersJob.perform_async('scheduler_token' => token) if verify_or_acquire!(token)
      end
    end

    def reset_bootstrap_for_test!
      @bootstrapped = false
    end
  end
end
