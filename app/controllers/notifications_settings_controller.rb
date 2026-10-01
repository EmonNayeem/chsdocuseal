# frozen_string_literal: true

class NotificationsSettingsController < ApplicationController
  before_action :load_bcc_config, only: :index
  before_action :load_reminder_config, only: :index
  authorize_resource :bcc_config, only: :index
  authorize_resource :reminder_config, only: :index

  before_action :build_account_config, only: :create
  authorize_resource :account_config, only: :create

  def index; end

  def create
    if @account_config.value.present? ? @account_config.save : @account_config.delete
      redirect_back fallback_location: settings_notifications_path, notice: I18n.t('changes_have_been_saved')
    else
      redirect_back fallback_location: settings_notifications_path, alert: I18n.t('unable_to_save')
    end
  end

  private

  def build_account_config
    @account_config =
      AccountConfig.find_or_initialize_by(account: current_account, key: email_config_params[:key])

    if @account_config.key == AccountConfig::SUBMITTER_REMINDERS
      @account_config.value = sanitize_and_prepare_reminder_config(
        @account_config.value,
        email_config_params[:value]
      )
    else
      @account_config.assign_attributes(email_config_params.except(:key))
    end
  end

  def sanitize_and_prepare_reminder_config(old_value, new_submitted_value)
    new_submitted_value ||= {}

    sanitized_value = {}
    %w[first_duration second_duration third_duration].each do |slot|
      next unless new_submitted_value.is_a?(ActionController::Parameters) || new_submitted_value.is_a?(Hash)

      val = new_submitted_value[slot]
      next unless AccountConfigs::REMINDER_DURATIONS.key?(val.to_s)

      sanitized_value[slot] = val.to_s
    end

    was_enabled = SubmitterReminders::Due.schedule_enabled?(old_value || {})
    is_enabled = SubmitterReminders::Due.schedule_enabled?(sanitized_value)

    if is_enabled && !was_enabled
      sanitized_value['enabled_at'] = Time.current.utc.iso8601
    elsif is_enabled && was_enabled
      old_enabled_at = (old_value || {})['enabled_at']
      sanitized_value['enabled_at'] = old_enabled_at.presence || Time.current.utc.iso8601
    end

    sanitized_value
  end

  def load_bcc_config
    @bcc_config =
      AccountConfig.find_or_initialize_by(account: current_account, key: AccountConfig::BCC_EMAILS)
  end

  def load_reminder_config
    @reminder_config =
      AccountConfig.find_or_initialize_by(account: current_account, key: AccountConfig::SUBMITTER_REMINDERS)
  end

  def email_config_params
    params.require(:account_config).permit(:key, :value, { value: {} }, { value: [] }).tap do |attrs|
      attrs[:key] = nil unless attrs[:key].in?([AccountConfig::BCC_EMAILS, AccountConfig::SUBMITTER_REMINDERS])
    end
  end
end
