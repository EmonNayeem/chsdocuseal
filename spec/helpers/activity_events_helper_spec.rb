# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityEventsHelper, type: :helper do
  describe '#activity_action_label' do
    it 'maps template actions correctly' do
      expect(helper.activity_action_label('template.created')).to eq('Created template')
      expect(helper.activity_action_label('template.updated')).to eq('Updated template')
      expect(helper.activity_action_label('template.archived')).to eq('Archived template')
      expect(helper.activity_action_label('template.deleted')).to eq('Deleted template')
    end

    it 'maps submission email delivery actions correctly' do
      expect(helper.activity_action_label('submission.email_sent')).to eq('Sent signature request email')
      expect(helper.activity_action_label('submission.reminder_email_sent')).to eq('Sent reminder email')
    end

    it 'maps submitter lifecycle actions correctly' do
      expect(helper.activity_action_label('submitter.viewed_form')).to eq('Viewed submission')
      expect(helper.activity_action_label('submitter.started_form')).to eq('Started submission')
      expect(helper.activity_action_label('submitter.completed_form')).to eq('Completed submission')
      expect(helper.activity_action_label('submitter.declined_form')).to eq('Declined submission')
      expect(helper.activity_action_label('submitter.delegated_form')).to eq('Delegated submission')
    end

    it 'falls back to humanize for unspecified actions' do
      expect(helper.activity_action_label('custom.unmapped_event')).to eq('Custom.unmapped event')
    end
  end

  describe '#activity_recipient_display_name' do
    it 'returns recipient_name when present' do
      event = build(
        :activity_event,
        metadata: { 'recipient_name' => 'CHS Contact', 'recipient_email' => 'contact@example.com' }
      )
      expect(helper.activity_recipient_display_name(event)).to eq('CHS Contact')
    end

    it 'falls back to recipient_email when recipient_name is blank' do
      event = build(
        :activity_event,
        metadata: { 'recipient_name' => '', 'recipient_email' => 'contact@example.com' }
      )
      expect(helper.activity_recipient_display_name(event)).to eq('contact@example.com')
    end

    it 'falls back to Recipient when both are unavailable' do
      event = build(:activity_event, metadata: {})
      expect(helper.activity_recipient_display_name(event)).to eq('Recipient')
    end
  end

  describe '#activity_metadata_summary' do
    it 'formats signature request email with name and email' do
      event = build(
        :activity_event,
        action: 'submission.email_sent',
        metadata: { 'recipient_name' => 'CHS Contact', 'recipient_email' => 'contact@example.com' }
      )
      expect(helper.activity_metadata_summary(event)).to eq('To: CHS Contact <contact@example.com>')
    end

    it 'formats signature request email with only email' do
      event = build(
        :activity_event,
        action: 'submission.email_sent',
        metadata: { 'recipient_name' => nil, 'recipient_email' => 'contact@example.com' }
      )
      expect(helper.activity_metadata_summary(event)).to eq('To: contact@example.com')
    end

    it 'formats reminder email with recipient and slot' do
      event = build(
        :activity_event,
        action: 'submission.reminder_email_sent',
        metadata: {
          'recipient_name' => 'CHS Contact',
          'recipient_email' => 'contact@example.com',
          'slot' => 'first_duration',
          'duration' => 'two_days'
        }
      )
      expected_summary = 'To: CHS Contact <contact@example.com> • Reminder: first_duration'
      expect(helper.activity_metadata_summary(event)).to eq(expected_summary)
    end
  end
end
