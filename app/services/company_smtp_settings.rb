# frozen_string_literal: true

class CompanySmtpSettings
  def self.resolve(company)
    return nil unless company&.smtp_enabled?
    return nil if company.smtp_address.blank? || company.smtp_port.blank?

    {
      address: company.smtp_address,
      port: company.smtp_port,
      domain: company.smtp_domain,
      user_name: company.smtp_user_name,
      password: company.smtp_password,
      authentication: company.smtp_password.present? ? (company.smtp_authentication.presence || 'plain') : nil,
      enable_starttls_auto: company.smtp_enable_starttls_auto,
      open_timeout: ActionMailerConfigsInterceptor::OPEN_TIMEOUT,
      read_timeout: ActionMailerConfigsInterceptor::READ_TIMEOUT
    }.compact_blank
  end

  def self.from_address(company)
    return nil unless company&.smtp_enabled? && company.smtp_from_email.present?

    name = company.smtp_from_name.presence || company.name
    %("#{name.to_s.delete('"')}" <#{company.smtp_from_email}>)
  end
end
