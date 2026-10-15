# frozen_string_literal: true

module ActivityEventsHelper
  ACTION_LABELS = {
    'recipient_contact.created' => 'Created recipient',
    'recipient_contact.updated' => 'Updated recipient',
    'recipient_contact.deleted' => 'Deleted recipient',
    'template.created' => 'Created template',
    'template.updated' => 'Updated template',
    'template.version_restored' => 'Restored template version',
    'template.archived' => 'Archived template',
    'template.deleted' => 'Deleted template',
    'submission.created' => 'Created submission',
    'submission.archived' => 'Archived submission',
    'submission.deleted' => 'Deleted submission',
    'submission.email_sent' => 'Sent signature request email',
    'submission.reminder_email_sent' => 'Sent reminder email',
    'submitter.viewed_form' => 'Viewed submission',
    'submitter.started_form' => 'Started submission',
    'submitter.completed_form' => 'Completed submission',
    'submitter.declined_form' => 'Declined submission',
    'submitter.delegated_form' => 'Delegated submission'
  }.freeze

  def activity_action_label(action)
    ACTION_LABELS[action] || action.to_s.humanize
  end

  def activity_company_badge(event)
    if event.visibility_scope == 'account'
      'Shared / Account'
    elsif event.company.present?
      event.company.name
    else
      'Company'
    end
  end

  def activity_metadata_summary(event)
    meta = event.metadata
    return if meta.blank?

    parts = []
    if event.action.in?(%w[submission.email_sent submission.reminder_email_sent])
      parts << activity_email_recipient_summary(meta)
      if event.action == 'submission.reminder_email_sent' && (meta['slot'].present? || meta['duration'].present?)
        parts << "Reminder: #{meta['slot'].presence || meta['duration']}"
      end
    elsif event.action == 'template.version_restored' && meta['version_number'].present?
      parts << "Version #{meta['version_number']}"
    else
      if meta['changed_fields'].present?
        fields = Array(meta['changed_fields']).map(&:humanize).join(', ')
        parts << "Changed: #{fields}"
      end
      parts << "Source: #{meta['source']}" if meta['source'].present?
    end

    parts.compact_blank.join(' • ').presence
  end

  def activity_recipient_display_name(event)
    meta = event.metadata || {}
    meta['recipient_name'].presence || meta['recipient_email'].presence || 'Recipient'
  end

  def activity_email_recipient_summary(meta)
    name = meta['recipient_name'].presence
    email = meta['recipient_email'].presence

    if name.present? && email.present?
      "To: #{name} <#{email}>"
    elsif email.present?
      "To: #{email}"
    elsif name.present?
      "To: #{name}"
    else
      'To: Recipient'
    end
  end

  def activity_compact_relative_time(time)
    return '' if time.blank?

    diff_seconds = (Time.current - time).to_i
    if diff_seconds < 60
      'just now'
    elsif diff_seconds < 3600
      "#{diff_seconds / 60}m ago"
    elsif diff_seconds < 86_400
      "#{diff_seconds / 3600}h ago"
    elsif diff_seconds < 172_800
      'yesterday'
    else
      time.strftime('%b %d')
    end
  end
end
