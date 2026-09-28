# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Submissions Send Email', :js do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:template) { create(:template, account: account, author: user, submitter_count: 2) }

  before do
    allow(Accounts).to receive(:can_send_emails?).and_return(true)
    sign_in(user)
  end

  it 'keeps save as default checkbox visible when toggling edit per party' do
    visit new_template_submission_path(template)

    expect(page).to have_content('Add New Recipients')

    find('label', text: /Edit message/i, match: :first).click

    expect(page).to have_content('Save as default template message')

    find('label', text: /Edit per party/i, match: :first).click

    expect(page).to have_content('Save as default template message')
  end
end
