# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitterReminders::NextDueSlot, type: :module do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user) }
  let(:submission) { create(:submission, template: template, account: account) }

  let(:submitter_uuid) { submission.template_submitters.first.fetch('uuid') }
  let(:submitter) do
    create(
      :submitter,
      submission: submission,
      uuid: submitter_uuid,
      sent_at: 2.days.ago,
      email: 'test@example.com'
    )
  end

  before do
    allow(SubmitterReminders::Due).to receive(:eligible?).and_return(true)
  end

  def create_reminder_config(hash)
    AccountConfig.create!(
      account: account,
      key: AccountConfig::SUBMITTER_REMINDERS,
      value: hash
    )
  end

  def create_delivery(slot, status, overrides = {})
    SubmitterReminderDelivery.create!({
      submitter: submitter,
      account: account,
      company_id: submitter.company_id,
      slot: slot,
      duration_key: 'dummy',
      due_at: 1.day.ago,
      status: status
    }.merge(overrides))
  end

  it 'A. no reminder config -> nil' do
    expect(described_class.call(submitter)).to be_nil
  end

  it 'B. first slot configured but not due -> nil' do
    create_reminder_config('first_duration' => 'three_days')
    # sent_at is 2 days ago, so due_at is 1 day in the future
    expect(described_class.call(submitter)).to be_nil
  end

  it 'C. first slot due, no claim -> first_duration' do
    create_reminder_config('first_duration' => 'twenty_four_hours')
    expect(described_class.call(submitter)).to eq('first_duration')
  end

  it 'D. first + second + third all overdue, no claims -> ONLY first_duration' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours',
      'third_duration' => 'four_hours'
    )
    expect(described_class.call(submitter)).to eq('first_duration')
  end

  it 'E. first sent, second and third overdue -> second_duration' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours',
      'third_duration' => 'four_hours'
    )
    create_delivery('first_duration', 'sent', sent_at: 2.days.ago)
    expect(described_class.call(submitter)).to eq('second_duration')
  end

  it 'F. first + second sent, third overdue -> third_duration' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours',
      'third_duration' => 'four_hours'
    )
    create_delivery('first_duration', 'sent', sent_at: 3.days.ago)
    create_delivery('second_duration', 'sent', sent_at: 2.days.ago)
    expect(described_class.call(submitter)).to eq('third_duration')
  end

  it 'G. all three sent -> nil' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours',
      'third_duration' => 'four_hours'
    )
    create_delivery('first_duration', 'sent', sent_at: 4.days.ago)
    create_delivery('second_duration', 'sent', sent_at: 3.days.ago)
    create_delivery('third_duration', 'sent', sent_at: 2.days.ago)
    expect(described_class.call(submitter)).to be_nil
  end

  it 'H. earliest due slot failed -> same earliest slot' do
    create_reminder_config('first_duration' => 'twenty_four_hours')
    create_delivery('first_duration', 'failed')
    expect(described_class.call(submitter)).to eq('first_duration')
  end

  it 'I. earliest due slot fresh pending -> nil' do
    create_reminder_config('first_duration' => 'twenty_four_hours')
    create_delivery('first_duration', 'pending', updated_at: 5.minutes.ago)
    expect(described_class.call(submitter)).to be_nil
  end

  it 'J. earliest due slot stale pending -> same earliest slot' do
    create_reminder_config('first_duration' => 'twenty_four_hours')
    create_delivery('first_duration', 'pending', updated_at: 20.minutes.ago)
    expect(described_class.call(submitter)).to eq('first_duration')
  end

  it 'K. last successful reminder less than 24h ago -> nil' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours'
    )
    create_delivery('first_duration', 'sent', sent_at: 12.hours.ago)
    expect(described_class.call(submitter)).to be_nil
  end

  it 'L. last successful reminder more than/equal 24h ago -> next eligible slot' do
    create_reminder_config(
      'first_duration' => 'one_hour',
      'second_duration' => 'two_hours'
    )
    create_delivery('first_duration', 'sent', sent_at: 25.hours.ago)
    expect(described_class.call(submitter)).to eq('second_duration')
  end

  it 'M. submitter not eligible -> nil' do
    create_reminder_config('first_duration' => 'twenty_four_hours')
    allow(SubmitterReminders::Due).to receive(:eligible?).with(submitter).and_return(false)
    expect(described_class.call(submitter)).to be_nil
  end

  it 'N. invalid duration key -> safely skip' do
    create_reminder_config(
      'first_duration' => 'invalid_key',
      'second_duration' => 'twenty_four_hours'
    )
    expect(described_class.call(submitter)).to eq('second_duration')
  end

  it 'O. slot absent from config -> safely skip' do
    create_reminder_config('second_duration' => 'twenty_four_hours')
    expect(described_class.call(submitter)).to eq('second_duration')
  end

  it 'P. nonascending schedules (leapfrog prevention): returns nil' do
    create_reminder_config(
      'first_duration' => 'seven_days',
      'second_duration' => 'twenty_four_hours'
    )
    # Day 2: second_duration chronologically due, but first_duration not due yet.
    # Must return nil to block leapfrogging.
    expect(described_class.call(submitter)).to be_nil
  end
end
