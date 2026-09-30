# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanSubmitterRemindersJob, type: :job do
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
    allow(SubmitterReminders::NextDueSlot).to receive(:call).and_return(nil)
    allow(SendSubmitterReminderEmailJob).to receive(:perform_async)
  end

  it 'enqueues exactly one worker job if candidate has due slot' do
    submitter # create candidate
    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')

    described_class.new.perform

    expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
      'submitter_id' => submitter.id,
      'slot' => 'first_duration'
    ).once
  end

  it 'enqueues exactly one job even if multiple overdue slots conceptually exist' do
    submitter # create candidate
    # NextDueSlot internally handles only returning one slot
    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('second_duration')

    described_class.new.perform

    expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
      'submitter_id' => submitter.id,
      'slot' => 'second_duration'
    ).once
  end

  it 'enqueues none if submitter is ineligible or has no due slot' do
    submitter # create candidate
    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return(nil)

    described_class.new.perform

    expect(SendSubmitterReminderEmailJob).not_to have_received(:perform_async)
  end

  it 'enqueues exactly one for each eligible submitter' do
    submitter1 = submitter
    submitter2 = create(
      :submitter,
      submission: submission,
      uuid: 'another-uuid',
      sent_at: 3.days.ago,
      email: 'test2@example.com'
    )

    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter1).and_return('first_duration')
    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter2).and_return('second_duration')

    described_class.new.perform

    expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
      'submitter_id' => submitter1.id,
      'slot' => 'first_duration'
    ).once

    expect(SendSubmitterReminderEmailJob).to have_received(:perform_async).with(
      'submitter_id' => submitter2.id,
      'slot' => 'second_duration'
    ).once
  end

  it 'filters obviously impossible candidates in DB scope' do
    # These should be filtered out by the DB query itself
    create(
      :submitter,
      submission: submission,
      uuid: 'no-email',
      sent_at: 2.days.ago,
      email: nil
    )
    create(
      :submitter,
      submission: submission,
      uuid: 'completed',
      sent_at: 2.days.ago,
      email: 'a@b.com',
      completed_at: Time.current
    )
    create(
      :submitter,
      submission: submission,
      uuid: 'declined',
      sent_at: 2.days.ago,
      email: 'a@b.com',
      declined_at: Time.current
    )
    create(
      :submitter,
      submission: submission,
      uuid: 'not-sent',
      sent_at: nil,
      email: 'a@b.com'
    )

    described_class.new.perform

    # NextDueSlot shouldn't even be called for these
    expect(SubmitterReminders::NextDueSlot).not_to have_received(:call)
  end

  it 'propagates systemic enqueue failures' do
    submitter # create candidate
    allow(SubmitterReminders::NextDueSlot).to receive(:call).with(submitter).and_return('first_duration')
    allow(SendSubmitterReminderEmailJob).to receive(:perform_async).and_raise(StandardError, 'Redis unavailable')

    expect do
      described_class.new.perform
    end.to raise_error(StandardError, 'Redis unavailable')
  end
end
