# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplateAnnotations do
  let(:valid_attachment_uuid) { SecureRandom.uuid }
  let(:pen_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'pen',
      'attachment_uuid' => valid_attachment_uuid,
      'page' => 0,
      'color' => '#1e293b',
      'width' => 0.004,
      'points' => [
        { 'x' => 0.1, 'y' => 0.2 },
        { 'x' => 0.3, 'y' => 0.4 }
      ]
    }
  end

  let(:highlighter_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'highlighter',
      'attachment_uuid' => valid_attachment_uuid,
      'page' => 1,
      'color' => '#facc15',
      'opacity' => 0.35,
      'width' => 0.025,
      'points' => [
        { 'x' => 0.15, 'y' => 0.25 },
        { 'x' => 0.45, 'y' => 0.25 }
      ]
    }
  end

  let(:text_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'text',
      'attachment_uuid' => valid_attachment_uuid,
      'page' => 0,
      'x' => 0.2,
      'y' => 0.3,
      'w' => 0.35,
      'h' => 0.08,
      'text' => 'Approved by supervisor',
      'color' => '#b91c1c',
      'font_size' => 14
    }
  end

  describe '.normalize' do
    it 'returns empty array for nil or non-array inputs' do
      expect(described_class.normalize(nil)).to eq([])
      expect(described_class.normalize('not an array')).to eq([])
      expect(described_class.normalize({})).to eq([])
    end

    it 'normalizes valid pen annotation' do
      res = described_class.normalize([pen_annotation])
      expect(res.size).to eq(1)
      item = res.first
      expect(item['type']).to eq('pen')
      expect(item['uuid']).to eq(pen_annotation['uuid'])
      expect(item['attachment_uuid']).to eq(valid_attachment_uuid)
      expect(item['page']).to eq(0)
      expect(item['color']).to eq('#1e293b')
      expect(item['width']).to eq(0.004)
      expect(item['points'].size).to eq(2)
      expect(item['points'].first).to eq({ 'x' => 0.1, 'y' => 0.2 })
    end

    it 'normalizes valid highlighter annotation' do
      res = described_class.normalize([highlighter_annotation])
      expect(res.size).to eq(1)
      item = res.first
      expect(item['type']).to eq('highlighter')
      expect(item['opacity']).to eq(0.35)
      expect(item['width']).to eq(0.025)
      expect(item['color']).to eq('#facc15')
    end

    it 'normalizes valid text annotation' do
      res = described_class.normalize([text_annotation])
      expect(res.size).to eq(1)
      item = res.first
      expect(item['type']).to eq('text')
      expect(item['text']).to eq('Approved by supervisor')
      expect(item['x']).to eq(0.2)
      expect(item['y']).to eq(0.3)
      expect(item['w']).to eq(0.35)
      expect(item['h']).to eq(0.08)
      expect(item['font_size']).to eq(14)
      expect(item['color']).to eq('#b91c1c')
    end

    it 'assigns a UUID if missing or blank' do
      annot = pen_annotation.except('uuid')
      res = described_class.normalize([annot])
      expect(res.first['uuid']).to be_present
    end

    it 'clamps out-of-bounds coordinates to 0..1' do
      annot = text_annotation.merge('x' => -0.5, 'y' => 1.5, 'w' => 2.0, 'h' => -1.0)
      res = described_class.normalize([annot])
      expect(res.first['x']).to eq(0.0)
      expect(res.first['y']).to eq(1.0)
      expect(res.first['w']).to eq(1.0)
      expect(res.first['h']).to eq(0.01)
    end

    it 'clamps point coordinates to 0..1' do
      annot = pen_annotation.merge(
        'points' => [
          { 'x' => -0.1, 'y' => 1.2 },
          { 'x' => 0.5, 'y' => 0.5 }
        ]
      )
      res = described_class.normalize([annot])
      expect(res.first['points'].first).to eq({ 'x' => 0.0, 'y' => 1.0 })
    end

    it 'discards points exceeding max points limit' do
      many_points = Array.new(6000) { |i| { 'x' => (i * 0.0001) % 1.0, 'y' => 0.5 } }
      annot = pen_annotation.merge('points' => many_points)
      res = described_class.normalize([annot])
      expect(res.first['points'].size).to eq(5000)
    end

    it 'truncates text exceeding 2000 characters' do
      long_text = 'A' * 2500
      annot = text_annotation.merge('text' => long_text)
      res = described_class.normalize([annot])
      expect(res.first['text'].length).to eq(2000)
    end

    it 'rejects annotations with unsupported type' do
      invalid = pen_annotation.merge('type' => 'circle')
      expect(described_class.normalize([invalid])).to be_empty
    end

    it 'rejects annotations without attachment_uuid' do
      invalid = pen_annotation.except('attachment_uuid')
      expect(described_class.normalize([invalid])).to be_empty
    end

    it 'rejects pen or highlighter annotations with fewer than 2 points' do
      invalid = pen_annotation.merge('points' => [{ 'x' => 0.1, 'y' => 0.2 }])
      expect(described_class.normalize([invalid])).to be_empty
    end

    it 'rejects text annotations with empty text' do
      invalid = text_annotation.merge('text' => '   ')
      expect(described_class.normalize([invalid])).to be_empty
    end

    it 'normalizes fallback colors for invalid color strings' do
      invalid_color = pen_annotation.merge('color' => 'javascript:alert(1)')
      res = described_class.normalize([invalid_color])
      expect(res.first['color']).to eq('#1e293b')
    end

    it 'supports rgba colors' do
      rgba_annot = highlighter_annotation.merge('color' => 'rgba(250, 204, 21, 0.4)')
      res = described_class.normalize([rgba_annot])
      expect(res.first['color']).to eq('rgba(250, 204, 21, 0.4)')
    end

    it 'normalizes pen thickness across presets and clamps extreme values' do
      thin = described_class.normalize([pen_annotation.merge('width' => 0.0015)]).first
      expect(thin['width']).to eq(0.0015)

      extra_thick = described_class.normalize([pen_annotation.merge('width' => 0.010)]).first
      expect(extra_thick['width']).to eq(0.010)

      too_thin = described_class.normalize([pen_annotation.merge('width' => 0.00001)]).first
      expect(too_thin['width']).to eq(0.0005)

      too_thick = described_class.normalize([pen_annotation.merge('width' => 0.5)]).first
      expect(too_thick['width']).to eq(0.05)
    end

    it 'normalizes highlighter thickness across presets and clamps extreme values' do
      thin = described_class.normalize([highlighter_annotation.merge('width' => 0.015)]).first
      expect(thin['width']).to eq(0.015)

      extra_thick = described_class.normalize([highlighter_annotation.merge('width' => 0.060)]).first
      expect(extra_thick['width']).to eq(0.060)

      too_thin = described_class.normalize([highlighter_annotation.merge('width' => 0.0001)]).first
      expect(too_thin['width']).to eq(0.005)

      too_thick = described_class.normalize([highlighter_annotation.merge('width' => 0.8)]).first
      expect(too_thick['width']).to eq(0.1)
    end

    it 'normalizes text font sizes and preserves backward compatibility' do
      custom_size = described_class.normalize([text_annotation.merge('font_size' => 28)]).first
      expect(custom_size['font_size']).to eq(28.0)

      clamped_small = described_class.normalize([text_annotation.merge('font_size' => 2)]).first
      expect(clamped_small['font_size']).to eq(6.0)

      clamped_large = described_class.normalize([text_annotation.merge('font_size' => 120)]).first
      expect(clamped_large['font_size']).to eq(72.0)

      # Backward compatibility: old text annotation without font_size
      legacy = text_annotation.except('font_size')
      legacy_res = described_class.normalize([legacy]).first
      expect(legacy_res['font_size']).to eq(14)
    end

    it 'rejects text annotations with NaN or Infinity coordinates safely' do
      nan_annot = text_annotation.merge('x' => 'NaN', 'y' => 0.5)
      inf_annot = text_annotation.merge('x' => 0.5, 'y' => 'Infinity')

      expect(described_class.normalize([nan_annot])).to eq([])
      expect(described_class.normalize([inf_annot])).to eq([])
    end

    it 'clamps out-of-bounds text geometry to keep it within page limits' do
      oob_annot = text_annotation.merge('x' => 1.5, 'y' => 1.5, 'w' => 0.5, 'h' => 0.5)
      normalized = described_class.normalize([oob_annot]).first

      expect(normalized).not_to be_nil
      expect(normalized['x']).to eq(1.0)
      expect(normalized['y']).to eq(1.0)
      expect(normalized['w']).to eq(0.01)
      expect(normalized['h']).to eq(0.01)
    end

    it 'validates page indices and rejects invalid or non-numeric values' do
      invalid_str_page = text_annotation.merge('page' => 'abc')
      negative_page = text_annotation.merge('page' => -1)
      excessive_page = text_annotation.merge('page' => 99_999)
      valid_str_page = text_annotation.merge('page' => '2')

      expect(described_class.normalize([invalid_str_page])).to eq([])
      expect(described_class.normalize([negative_page])).to eq([])
      expect(described_class.normalize([excessive_page])).to eq([])

      res = described_class.normalize([valid_str_page]).first
      expect(res['page']).to eq(2)
    end

    it 'caps excessively large annotation collections to MAX_ANNOTATIONS_COUNT' do
      large_list = Array.new(1200) { pen_annotation.deep_dup }
      res = described_class.normalize(large_list)
      expect(res.size).to eq(described_class::MAX_ANNOTATIONS_COUNT)
    end

    it 'normalizes malformed or unsafe colors to DEFAULT_COLOR' do
      malformed_color = text_annotation.merge('color' => '<script>alert(1)</script>')
      res = described_class.normalize([malformed_color]).first
      expect(res['color']).to eq(described_class::DEFAULT_COLOR)
    end
  end

  describe '.clean_orphaned' do
    let(:doc1_uuid) { SecureRandom.uuid }
    let(:doc2_uuid) { SecureRandom.uuid }
    let(:orphan_uuid) { SecureRandom.uuid }

    let(:annotations) do
      [
        pen_annotation.merge('attachment_uuid' => doc1_uuid),
        highlighter_annotation.merge('attachment_uuid' => doc2_uuid),
        text_annotation.merge('attachment_uuid' => orphan_uuid)
      ]
    end

    it 'removes annotations whose attachment_uuid is not in the valid list' do
      valid_uuids = [doc1_uuid, doc2_uuid]
      cleaned = described_class.clean_orphaned(annotations, valid_uuids)

      expect(cleaned.size).to eq(2)
      expect(cleaned.pluck('attachment_uuid')).to contain_exactly(doc1_uuid, doc2_uuid)
    end

    it 'returns empty if valid_uuids is empty' do
      expect(described_class.clean_orphaned(annotations, [])).to eq([])
    end
  end

  describe '.remap_attachments' do
    let(:old_uuid1) { SecureRandom.uuid }
    let(:new_uuid1) { SecureRandom.uuid }
    let(:orphan_uuid) { SecureRandom.uuid }

    let(:annotations) do
      [
        pen_annotation.merge('attachment_uuid' => old_uuid1),
        text_annotation.merge('attachment_uuid' => orphan_uuid)
      ]
    end

    it 'remaps attachment_uuid and assigns fresh annotation UUIDs' do
      mapping = { old_uuid1 => new_uuid1 }
      remapped = described_class.remap_attachments(annotations, mapping)

      expect(remapped.size).to eq(1)
      item = remapped.first
      expect(item['attachment_uuid']).to eq(new_uuid1)
      expect(item['uuid']).not_to eq(pen_annotation['uuid'])
      expect(item['type']).to eq('pen')
    end
  end
end
