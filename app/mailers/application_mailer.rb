# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'DocuSeal <info@docuseal.com>'
  layout 'mailer'

  register_interceptor ActionMailerConfigsInterceptor
  register_interceptor HtmlToPlainTextInterceptor
  register_preview_interceptor HtmlToPlainTextInterceptor

  register_observer ActionMailerEventsObserver

  before_action do
    ActiveStorage::Current.url_options = Docuseal.default_url_options
  end

  after_action :set_message_metadata
  after_action :set_message_uuid

  def default_url_options
    Docuseal.default_url_options.merge(host: ENV.fetch('EMAIL_HOST', Docuseal.default_url_options[:host]))
  end

  def set_message_metadata
    message.instance_variable_set(:@message_metadata, @message_metadata || {})
  end

  def set_message_uuid
    message['X-Message-Uuid'] = SecureRandom.uuid
  end

  def assign_message_metadata(tag, record)
    @message_metadata = (@message_metadata || {}).merge(
      'tag' => tag,
      'record_id' => record.id,
      'record_type' => record.class.name
    )

    company_id = company_id_for_message_metadata(record)
    @message_metadata['company_id'] = company_id if company_id
  end

  def put_metadata(attrs)
    @message_metadata = (@message_metadata || {}).merge(attrs)
  end

  helper_method :branded_company_name_for

  def branded_company_name_for(record, fallback: nil)
    company_id = company_id_for_message_metadata(record)
    company = Company.find_by(id: company_id) if company_id

    if company
      company.branded_name
    else
      fallback
    end
  rescue StandardError
    fallback
  end

  private

  def company_id_for_message_metadata(record)
    return nil unless record

    if record.respond_to?(:company_id) && record.company_id.present?
      record.company_id
    elsif record.respond_to?(:submission) && record.submission&.company_id.present?
      record.submission.company_id
    elsif record.respond_to?(:template) && record.template&.company_id.present?
      record.template.company_id
    elsif record.respond_to?(:company) && record.company&.id.present?
      record.company.id
    end
  rescue StandardError
    nil
  end
end
