# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications Settings', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in(user)
  end

  describe 'POST /settings/notifications' do
    let(:valid_duration) { AccountConfigs::REMINDER_DURATIONS.keys.sample }

    context 'when saving submitter reminders' do
      it 'first valid reminder schedule save -> enabled_at gets assigned' do
        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: valid_duration
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config.value['first_duration']).to eq(valid_duration)
        expect(config.value['enabled_at']).to be_present
        expect { Time.iso8601(config.value['enabled_at']) }.not_to raise_error
      end

      it 'editing an already-enabled schedule -> enabled_at is preserved exactly' do
        old_time = 1.day.ago.utc.iso8601
        AccountConfig.create!(
          account: account,
          key: AccountConfig::SUBMITTER_REMINDERS,
          value: { 'first_duration' => valid_duration, 'enabled_at' => old_time }
        )

        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: valid_duration,
              second_duration: valid_duration
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config.value['second_duration']).to eq(valid_duration)
        expect(config.value['enabled_at']).to eq(old_time)
      end

      it 'existing valid schedule but missing enabled_at -> edit while still enabled -> enabled_at assigned' do
        AccountConfig.create!(
          account: account,
          key: AccountConfig::SUBMITTER_REMINDERS,
          value: { 'first_duration' => valid_duration }
        )

        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: valid_duration,
              second_duration: valid_duration
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config.value['second_duration']).to eq(valid_duration)
        expect(config.value['enabled_at']).to be_present
        expect { Time.iso8601(config.value['enabled_at']) }.not_to raise_error
      end

      it 'disabling all reminder durations -> enabled_at removed (and config deleted if empty)' do
        AccountConfig.create!(
          account: account,
          key: AccountConfig::SUBMITTER_REMINDERS,
          value: { 'first_duration' => valid_duration, 'enabled_at' => 1.day.ago.utc.iso8601 }
        )

        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: ''
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config).to be_nil
      end

      it 're-enabling after disable -> new enabled_at is later/new' do
        AccountConfig.create!(
          account: account,
          key: AccountConfig::SUBMITTER_REMINDERS,
          value: { 'enabled_at' => 1.day.ago.utc.iso8601 }
        )

        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: valid_duration
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config.value['enabled_at']).to be_present
        expect(config.value['enabled_at']).not_to eq(1.day.ago.utc.iso8601)
      end

      it 'client-supplied enabled_at is ignored' do
        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: valid_duration,
              enabled_at: 1.year.ago.utc.iso8601
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config.value['enabled_at']).to be_present
        expect(config.value['enabled_at']).not_to eq(1.year.ago.utc.iso8601)
      end

      it 'invalid duration values do not make schedule enabled' do
        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::SUBMITTER_REMINDERS,
            value: {
              first_duration: 'invalid_duration_string'
            }
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::SUBMITTER_REMINDERS)
        expect(config).to be_nil
      end

      it 'BCC settings behavior is unaffected' do
        post settings_notifications_path, params: {
          account_config: {
            key: AccountConfig::BCC_EMAILS,
            value: 'test@example.com'
          }
        }

        config = account.account_configs.find_by(key: AccountConfig::BCC_EMAILS)
        expect(config.value).to eq('test@example.com')
      end
    end
  end
end
