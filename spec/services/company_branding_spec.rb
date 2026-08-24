# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CompanyBranding do
  describe 'presets' do
    it 'returns CHS preset for CHS code' do
      company = Company.new(code: 'CHS', branding_enabled: false)
      branding = described_class.new(company)

      expect(branding.site_name).to eq('eDocument Centre - Churchfield Home Services')
      expect(branding.logo_url).to eq('/brand-assets/chs/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/chs/favicon.svg')
    end

    it 'returns MD preset for MD code' do
      company = Company.new(code: 'MD', branding_enabled: false)
      branding = described_class.new(company)

      expect(branding.site_name).to eq('eDocument Centre - Materials Direct')
      expect(branding.logo_url).to eq('/brand-assets/md/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/md/favicon.svg')
    end

    it 'returns SL preset for SL code' do
      company = Company.new(code: 'SL', branding_enabled: false)
      branding = described_class.new(company)

      expect(branding.site_name).to eq('eDocument Centre - Smart Lotto')
      expect(branding.logo_url).to eq('/brand-assets/sl/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/sl/favicon.svg')
    end

    it 'returns ESS preset for ESS code' do
      company = Company.new(code: 'ESS', branding_enabled: false)
      branding = described_class.new(company)

      expect(branding.site_name).to eq('eDocument Centre - Efficient Software Solutions')
      expect(branding.logo_url).to eq('/brand-assets/ess/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/ess/favicon.svg')
    end

    it 'returns default preset when no code matches' do
      company = Company.new(code: 'UNKNOWN', branding_enabled: false)
      branding = described_class.new(company)

      expect(branding.site_name).to eq('eDocument Centre')
      expect(branding.logo_url).to eq('/brand-assets/chs/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/chs/favicon.svg')
    end
  end

  describe 'overrides' do
    let(:company) do
      Company.new(
        code: 'CHS',
        branding_enabled: true,
        brand_name: 'Custom Brand'
      )
    end
    let(:branding) { described_class.new(company) }

    it 'uses custom brand name when enabled' do
      expect(branding.site_name).to eq('Custom Brand')
    end

    it 'ignores brand_logo_key and brand_icon_key overrides' do
      company.brand_logo_key = '/custom-logo.png'
      company.brand_icon_key = '/custom-icon.png'
      expect(branding.logo_url).to eq('/brand-assets/chs/logo.svg')
      expect(branding.favicon_url).to eq('/brand-assets/chs/favicon.svg')
    end
  end

  describe 'when disabled' do
    let(:company) do
      Company.new(code: 'CHS', branding_enabled: false, brand_name: 'Custom Brand')
    end
    let(:branding) { described_class.new(company) }

    it 'ignores custom brand name and uses preset' do
      expect(branding.site_name).to eq('eDocument Centre - Churchfield Home Services')
    end
  end
end
