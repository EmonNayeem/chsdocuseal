# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterReminders::ScannerLease, type: :module do
  let(:config_mock) { instance_double(Sidekiq::Config) }
  let(:redis_mock) { instance_double(RedisClient) }
  let(:token) { 'dummy-uuid' }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis_mock)
    allow(ScanSubmitterRemindersJob).to receive(:perform_async)
    allow(SecureRandom).to receive(:uuid).and_return(token)
    described_class.reset_bootstrap_for_test!
  end

  describe '.bootstrap!' do
    context 'when not in test environment' do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      it 'registers startup hook' do
        allow(config_mock).to receive(:on).with(:startup)
        described_class.bootstrap!(config_mock)
        expect(config_mock).to have_received(:on).with(:startup)
      end

      it 'ensures single registration per runtime' do
        allow(config_mock).to receive(:on).with(:startup)
        described_class.bootstrap!(config_mock)
        described_class.bootstrap!(config_mock)
        expect(config_mock).to have_received(:on).with(:startup).once
      end
    end

    it 'does not register startup hook in test environment' do
      allow(Rails.env).to receive(:test?).and_return(true)
      allow(config_mock).to receive(:on)
      described_class.bootstrap!(config_mock)
      expect(config_mock).not_to have_received(:on)
    end
  end

  describe 'startup hook behavior' do
    before do
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(config_mock).to receive(:on).with(:startup).and_yield
    end

    it 'bootstrap acquires empty lease -> generates token -> enqueues scanner' do
      allow(redis_mock).to receive(:call)
        .with('EVAL', anything, 1, described_class::KEY, token, described_class::TTL.to_s)
        .and_return(1)

      described_class.bootstrap!(config_mock)

      expect(ScanSubmitterRemindersJob).to have_received(:perform_async)
        .with('scheduler_token' => token).once
    end

    it 'bootstrap cannot acquire existing lease -> no scanner enqueue' do
      allow(redis_mock).to receive(:call)
        .with('EVAL', anything, 1, described_class::KEY, token, described_class::TTL.to_s)
        .and_return(0)

      described_class.bootstrap!(config_mock)

      expect(ScanSubmitterRemindersJob).not_to have_received(:perform_async)
    end

    it 'bootstrap Redis failure -> propagates -> is NOT silently swallowed' do
      allow(redis_mock).to receive(:call).and_raise(StandardError, 'Redis offline')

      expect { described_class.bootstrap!(config_mock) }.to raise_error(StandardError, 'Redis offline')
      expect(ScanSubmitterRemindersJob).not_to have_received(:perform_async)
    end
  end

  describe '.verify_or_acquire!' do
    it 'returns true when Lua script returns 1 (meaning either empty lease acquired OR same token refreshed)' do
      allow(redis_mock).to receive(:call)
        .with('EVAL', anything, 1, described_class::KEY, token, described_class::TTL.to_s)
        .and_return(1)

      expect(described_class.verify_or_acquire!(token)).to be true
    end

    it 'returns false when Lua script returns 0 (meaning owned by another token)' do
      allow(redis_mock).to receive(:call)
        .with('EVAL', anything, 1, described_class::KEY, token, described_class::TTL.to_s)
        .and_return(0)

      expect(described_class.verify_or_acquire!(token)).to be false
    end
  end
end
