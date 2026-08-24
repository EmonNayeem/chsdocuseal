# frozen_string_literal: true

class CompanyBranding
  attr_reader :company, :preset

  PRESETS = {
    'CHS' => {
      site_name: 'eDocument Centre - Churchfield Home Services',
      logo_url: '/brand-assets/chs/logo.svg',
      favicon_url: '/brand-assets/chs/favicon.svg'
    },
    'MD' => {
      site_name: 'eDocument Centre - Materials Direct',
      logo_url: '/brand-assets/md/logo.svg',
      favicon_url: '/brand-assets/md/favicon.svg'
    },
    'SL' => {
      site_name: 'eDocument Centre - Smart Lotto',
      logo_url: '/brand-assets/sl/logo.svg',
      favicon_url: '/brand-assets/sl/favicon.svg'
    },
    'ESS' => {
      site_name: 'eDocument Centre - Efficient Software Solutions',
      logo_url: '/brand-assets/ess/logo.svg',
      favicon_url: '/brand-assets/ess/favicon.svg'
    }
  }.freeze

  DEFAULT = {
    site_name: 'eDocument Centre',
    logo_url: '/brand-assets/chs/logo.svg',
    favicon_url: '/brand-assets/chs/favicon.svg'
  }.freeze

  def initialize(company)
    @company = company
    @preset = PRESETS[@company&.code] || DEFAULT
  end

  def site_name
    return @preset[:site_name] unless @company&.branding_enabled?

    @company.brand_name.presence || @preset[:site_name]
  end

  def logo_url
    @preset[:logo_url]
  end

  def favicon_url
    @preset[:favicon_url]
  end

  def to_h
    {
      site_name: site_name,
      logo_url: logo_url,
      favicon_url: favicon_url
    }
  end
end
