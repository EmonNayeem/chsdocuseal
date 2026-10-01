# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Builder Branding', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in(user)
  end

  def company_for(code)
    account.companies.find_by!(code: code)
  end

  it 'renders CHS logo URL for CHS-owned template' do
    company = company_for('CHS')
    user.update!(company: company)
    template = create(:template, account: account, author: user, company: company)

    get edit_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-logo-url="/brand-assets/chs/logo.svg"')
    expect(response.body).to include('data-logo-alt="eDocument Centre - Churchfield Home Services"')
  end

  it 'renders MD logo URL for MD-owned template' do
    company = company_for('MD')
    user.update!(company: company)
    template = create(:template, account: account, author: user, company: company)

    get edit_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-logo-url="/brand-assets/md/logo.svg"')
    expect(response.body).to include('data-logo-alt="eDocument Centre - Materials Direct"')
  end

  it 'renders SL logo URL for SL-owned template' do
    company = company_for('SL')
    user.update!(company: company)
    template = create(:template, account: account, author: user, company: company)

    get edit_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-logo-url="/brand-assets/sl/logo.svg"')
    expect(response.body).to include('data-logo-alt="eDocument Centre - Smart Lotto"')
  end

  it 'renders ESS logo URL for ESS-owned template' do
    company = company_for('ESS')
    user.update!(company: company)
    template = create(:template, account: account, author: user, company: company)

    get edit_template_path(template)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-logo-url="/brand-assets/ess/logo.svg"')
    expect(response.body).to include('data-logo-alt="eDocument Centre - Efficient Software Solutions"')
  end
end
