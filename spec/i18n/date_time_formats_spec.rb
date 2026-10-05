# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe I18n do
  # rubocop:enable RSpec/SpecFilePathFormat
  describe 'short format' do
    let(:test_time) { Time.zone.parse('2026-10-02 13:32:00') }
    let(:test_date) { Date.new(2026, 10, 2) }

    it 'formats Time correctly in en' do
      expect(described_class.l(test_time, format: :short, locale: :en)).to eq('02 Oct 26 01:32 PM')
    end

    it 'formats Date correctly in en' do
      expect(described_class.l(test_date, format: :short, locale: :en)).to eq('02 Oct 26')
    end

    it 'formats Time correctly in en-US' do
      expect(described_class.l(test_time, format: :short, locale: :'en-US')).to eq('02 Oct 26 01:32 PM')
    end

    it 'formats Time correctly in en-GB' do
      expect(described_class.l(test_time, format: :short, locale: :'en-GB')).to eq('02 Oct 26 01:32 PM')
    end

    it 'formats Time using month abbreviations in another locale (e.g. es)' do
      # In Spanish, October is "oct" or "oct."
      # But the key is that it's using the %b localized translation and %d %b %y format.
      formatted = described_class.l(test_time, format: :short, locale: :es)
      expect(formatted).to match(/02 \w+\.? 26 01:32 PM/)
    end
  end
end
