# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Submissions Timestamp', type: :request do
  let(:account) { create(:account, timezone: 'Asia/Tokyo') }
  let(:user) { create(:user, account: account) }

  let(:template_single) do
    create(:template, account: account, author: user, submitter_count: 1)
  end

  let(:template_multi) do
    create(:template, account: account, author: user, submitter_count: 2)
  end

  before do
    sign_in(user)
  end

  it 'renders the status timestamp on a single-submitter submission exactly once' do
    submission = create(
      :submission,
      :with_submitters,
      template: template_single,
      created_by_user: user,
      account: account,
      created_at: Time.utc(2026, 10, 1, 12, 0, 0)
    )

    submitter = submission.submitters.first
    event_time = Time.utc(2026, 10, 2, 13, 0, 0)
    submitter.update!(opened_at: event_time)

    expect(submission.submitters.size).to eq(1)

    get template_path(template_single)
    expect(response).to have_http_status(:ok)

    expected_time = I18n.l(
      submitter.status_event_at.in_time_zone(account.timezone),
      format: :short,
      locale: account.locale
    )

    document = Nokogiri::HTML(response.body)
    timestamps = document.css('.submission-status-time')

    expect(timestamps.size).to eq(1)
    expect(timestamps.first.text.strip).to eq(expected_time)
  end

  it 'renders the status timestamp for each submitter on an active multi-submitter submission' do
    submission = create(
      :submission,
      :with_submitters,
      template: template_multi,
      created_by_user: user,
      account: account,
      created_at: Time.utc(2026, 10, 1, 12, 0, 0)
    )

    first_time = Time.utc(2026, 10, 2, 13, 1, 0)
    second_time = Time.utc(2026, 10, 2, 13, 2, 0)
    submission.submitters.first.update!(opened_at: first_time)
    submission.submitters.second.update!(sent_at: second_time)

    expect(submission.submitters.size).to eq(2)

    get template_path(template_multi)
    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    timestamps = document.css('.submission-status-time')

    expect(timestamps.size).to eq(2)
    first_time_formatted = I18n.l(
      submission.submitters.first.status_event_at.in_time_zone(account.timezone),
      format: :short,
      locale: account.locale
    )
    second_time_formatted = I18n.l(
      submission.submitters.second.status_event_at.in_time_zone(account.timezone),
      format: :short,
      locale: account.locale
    )

    expect(timestamps[0].text.strip).to eq(first_time_formatted)
    expect(timestamps[1].text.strip).to eq(second_time_formatted)
  end

  it 'renders exactly one overall completed timestamp for a completed multi-submitter submission' do
    submission = create(
      :submission,
      :with_submitters,
      template: template_multi,
      created_by_user: user,
      account: account,
      created_at: Time.utc(2026, 10, 1, 12, 0, 0)
    )

    first_completed_at = Time.utc(2026, 10, 2, 13, 1, 0)
    second_completed_at = Time.utc(2026, 10, 2, 14, 0, 0)

    submission.submitters.first.update!(completed_at: first_completed_at)
    submission.submitters.second.update!(completed_at: second_completed_at)
    submission.update!(completed_at: second_completed_at)

    get template_path(template_multi)
    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    timestamps = document.css('.submission-status-time')

    latest_submitter = submission.submitters.select(&:completed_at?).max_by(&:completed_at)

    expected_time = I18n.l(
      latest_submitter.status_event_at.in_time_zone(account.timezone),
      format: :short,
      locale: account.locale
    )

    expect(timestamps.size).to eq(1)
    expect(timestamps.first.text.strip).to eq(expected_time)
  end

  it 'renders the expire_at timestamp when the submission is expired' do
    submission = create(
      :submission,
      :with_submitters,
      template: template_single,
      created_by_user: user,
      account: account,
      created_at: Time.utc(2026, 10, 1, 12, 0, 0),
      expire_at: Time.utc(2026, 10, 5, 12, 0, 0)
    )

    submission.update!(expire_at: Time.utc(2026, 10, 1, 11, 0, 0)) # make it in the past so it's expired

    get template_path(template_single)
    expect(response).to have_http_status(:ok)

    document = Nokogiri::HTML(response.body)
    timestamps = document.css('.submission-status-time')

    expected_time = I18n.l(
      submission.expire_at.in_time_zone(account.timezone),
      format: :short,
      locale: account.locale
    )

    expect(timestamps.size).to eq(1)
    expect(timestamps.first.text.strip).to eq(expected_time)
  end
end
