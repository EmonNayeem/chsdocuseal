# frozen_string_literal: true

if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    SubmitterReminders::ScannerLease.bootstrap!(config)
  end
end

ActiveSupport.on_load(:sidekiq_config) do |config|
  SubmitterReminders::ScannerLease.bootstrap!(config)
end
