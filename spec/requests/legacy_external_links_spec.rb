# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legacy External Links and Attribution', type: :request do
  describe 'GET /settings/api (API Settings)' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account:) }

    before do
      login_as(user, scope: :user)
    end

    it 'renders API settings without legacy external DocuSeal API docs button' do
      get settings_api_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('https://www.docuseal.com/docs/api')
      expect(response.body).not_to include(I18n.t('open_full_api_reference'))

      # Preserves functional API controls and endpoint examples
      expect(response.body).to include('X-Auth-Token')
      expect(response.body).to include('curl')
    end
  end

  describe 'GET / (Logged-out Landing Page)' do
    before do
      create(:user)
    end

    it 'renders homepage with environment-aware eDC link and distinct upstream DocuSeal attribution' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('eDocument Centre')

      # Visible eDocument Centre product link resolves to environment-aware root URL, not docuseal.com
      app_root = Rails.application.routes.url_helpers.root_url(Docuseal.default_url_options)
      expect(response.body).to include("<a href=\"#{app_root}\" class=\"underline\">eDocument Centre</a>")
      expect(response.body).not_to include('<a href="https://www.docuseal.com" class="underline">eDocument Centre</a>')
      expect(response.body).not_to include('<a href="https://www.docuseal.com/" class="underline">eDocument Centre</a>')

      # Legally required upstream DocuSeal attribution is retained and clearly distinguished
      expect(response.body).to include(I18n.t('powered_by'))
      expected_docuseal_link =
        "<a href=\"#{Docuseal::PRODUCT_URL}\" class=\"underline\" target=\"_blank\" rel=\"noopener\">DocuSeal</a>"
      expect(response.body).to include(expected_docuseal_link)
      expect(response.body).to include(I18n.t('open_source_documents_software'))

      # Open Source card acknowledges AGPLv3 and upstream DocuSeal without promotional marketing text
      expect(response.body).to include('AGPLv3')
      expected_github_link =
        "<a href=\"#{Docuseal::GITHUB_URL}\" " \
        'class="link link-neutral font-bold" target="_blank" rel="noopener">DocuSeal</a>'
      expect(response.body).to include(expected_github_link)
      expect(response.body).not_to include('Open-source contributors are always ready to help!')
    end
  end
end
