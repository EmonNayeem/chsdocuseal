# frozen_string_literal: true

module ActionMailerConfigsInterceptor
  OPEN_TIMEOUT = ENV.fetch('SMTP_OPEN_TIMEOUT', '15').to_i
  READ_TIMEOUT = ENV.fetch('SMTP_READ_TIMEOUT', '25').to_i

  module_function

  def delivering_email(message)
    return message unless Rails.env.production?

    if Docuseal.demo?
      message.delivery_method(:test)

      return message
    end

    return message if apply_company_smtp_settings(message)

    if Rails.env.production? && Rails.application.config.action_mailer.delivery_method
      from = ENV.fetch('SMTP_FROM').to_s.split(',').sample

      if from.match?(User::FULL_EMAIL_REGEXP)
        message[:from] = message[:from].to_s.sub(User::EMAIL_REGEXP, from)
      else
        message.from = from
      end

      return message
    end

    unless Docuseal.multitenant?
      email_configs = EncryptedConfig.order(:account_id).find_by(key: EncryptedConfig::EMAIL_SMTP_KEY)

      if email_configs
        message.delivery_method(:smtp, build_smtp_configs_hash(email_configs))

        message.from = %("#{email_configs.account.name.to_s.delete('"')}" <#{email_configs.value['from_email']}>)
      else
        message.delivery_method(:test)
      end
    end

    message
  end

  def build_smtp_configs_hash(email_configs)
    value = email_configs.value

    is_tls = value['security'] == 'tls' || (value['security'].blank? && value['port'].to_s == '465')
    is_ssl = value['security'] == 'ssl'
    is_noverify = value['security'] == 'noverify'

    enable_starttls = is_noverify ? :enable_starttls_auto : :enable_starttls

    {
      user_name: value['username'],
      password: value['password'],
      address: value['host'],
      port: value['port'],
      domain: value['domain'],
      openssl_verify_mode: is_noverify ? OpenSSL::SSL::VERIFY_NONE : nil,
      authentication: value['password'].present? ? value.fetch('authentication', 'plain') : nil,
      enable_starttls => !is_tls && !is_ssl,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      ssl: is_ssl,
      tls: is_tls
    }.compact_blank
  end

  def apply_company_smtp_settings(message)
    metadata = message.instance_variable_get(:@message_metadata)
    return false unless metadata.is_a?(Hash)

    company_id = metadata['company_id'] || metadata[:company_id]
    return false if company_id.blank?

    company = Company.find_by(id: company_id)
    return false unless company

    settings = CompanySmtpSettings.resolve(company)
    return false unless settings

    message.delivery_method(:smtp, settings)

    from_address = CompanySmtpSettings.from_address(company)
    message.from = from_address if from_address.present?

    true
  rescue StandardError => e
    Rails.logger.warn("Company SMTP interceptor fell back after #{e.class.name}") if defined?(Rails.logger)
    false
  end
end
