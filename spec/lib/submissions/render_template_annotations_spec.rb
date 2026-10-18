# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::RenderTemplateAnnotations do
  let(:attachment_uuid) { SecureRandom.uuid }
  let(:other_attachment_uuid) { SecureRandom.uuid }

  let(:pen_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'pen',
      'attachment_uuid' => attachment_uuid,
      'page' => 0,
      'color' => '#1e293b',
      'width' => 0.005,
      'points' => [
        { 'x' => 0.1, 'y' => 0.2 },
        { 'x' => 0.5, 'y' => 0.6 }
      ]
    }
  end

  let(:highlighter_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'highlighter',
      'attachment_uuid' => attachment_uuid,
      'page' => 0,
      'color' => '#facc15',
      'opacity' => 0.4,
      'width' => 0.03,
      'points' => [
        { 'x' => 0.2, 'y' => 0.3 },
        { 'x' => 0.8, 'y' => 0.3 }
      ]
    }
  end

  let(:text_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'text',
      'attachment_uuid' => attachment_uuid,
      'page' => 0,
      'x' => 0.15,
      'y' => 0.25,
      'w' => 0.4,
      'h' => 0.1,
      'text' => "Line 1\nLine 2",
      'color' => '#b91c1c',
      'font_size' => 16
    }
  end

  let(:other_doc_annotation) do
    {
      'uuid' => SecureRandom.uuid,
      'type' => 'pen',
      'attachment_uuid' => other_attachment_uuid,
      'page' => 0,
      'color' => '#000000',
      'width' => 0.005,
      'points' => [
        { 'x' => 0.1, 'y' => 0.1 },
        { 'x' => 0.2, 'y' => 0.2 }
      ]
    }
  end

  let(:hexapdf_doc) do
    doc = HexaPDF::Document.new
    doc.pages.add([0, 0, 612, 792])
    doc
  end

  it 'renders pen, highlighter, and text annotations onto the PDF canvas without error' do
    annotations = [pen_annotation, highlighter_annotation, text_annotation, other_doc_annotation]

    described_class.call(
      doc: hexapdf_doc,
      attachment_uuid: attachment_uuid,
      annotations: annotations
    )

    out = StringIO.new
    expect { hexapdf_doc.write(out) }.not_to raise_error
    expect(out.string.size).to be > 0
  end

  it 'gracefully ignores malformed annotations without raising an error or crashing PDF generation' do
    malformed = [
      { 'type' => 'unknown', 'attachment_uuid' => attachment_uuid, 'page' => 0 },
      { 'type' => 'pen', 'attachment_uuid' => attachment_uuid, 'page' => 0, 'points' => [] },
      { 'type' => 'text', 'attachment_uuid' => attachment_uuid, 'page' => 0, 'text' => nil },
      { 'type' => 'pen', 'attachment_uuid' => attachment_uuid, 'page' => 999 } # out-of-range page
    ]

    expect do
      described_class.call(
        doc: hexapdf_doc,
        attachment_uuid: attachment_uuid,
        annotations: malformed
      )
    end.not_to raise_error

    out = StringIO.new
    expect { hexapdf_doc.write(out) }.not_to raise_error
  end

  it 'does nothing if annotations is blank' do
    described_class.call(
      doc: hexapdf_doc,
      attachment_uuid: attachment_uuid,
      annotations: []
    )

    out = StringIO.new
    expect { hexapdf_doc.write(out) }.not_to raise_error
  end

  it 'correctly handles pages with nonzero box origins and rotated pages' do
    doc = HexaPDF::Document.new
    page = doc.pages.add([36, 36, 648, 828])
    page.rotate(90)

    described_class.call(
      doc: doc,
      attachment_uuid: attachment_uuid,
      annotations: [pen_annotation, text_annotation]
    )

    out = StringIO.new
    expect { doc.write(out) }.not_to raise_error
    expect(out.string.size).to be > 0
  end

  it 'gracefully handles text containing glyphs missing in standard fonts' do
    unicode_text = text_annotation.merge('text' => "English \u09AC\u09BE\u0982\u09B2\u09BE \u{1F600}")

    described_class.call(
      doc: hexapdf_doc,
      attachment_uuid: attachment_uuid,
      annotations: [unicode_text]
    )

    out = StringIO.new
    expect { hexapdf_doc.write(out) }.not_to raise_error
    expect(out.string.size).to be > 0
  end

  it 'rescues canvas text errors and attempts ASCII sanitized fallback' do
    canvas = instance_double(HexaPDF::Content::Canvas)
    missing_glyph_error = HexaPDF::MissingGlyphError.allocate
    allow(missing_glyph_error).to receive(:message).and_return('Missing glyph for character: €')
    allow(canvas).to receive(:text).with('Special € Symbol', at: [10, 20]).and_raise(missing_glyph_error)
    allow(canvas).to receive(:text).with('Special ? Symbol', at: [10, 20])

    described_class.draw_text_line_safely(canvas, 'Special € Symbol', 10, 20)

    expect(canvas).to have_received(:text).with('Special ? Symbol', at: [10, 20])
  end

  it 'rescues unexpected annotation exceptions, logs them, and proceeds with other annotations' do
    allow(described_class).to receive(:render_single_annotation).and_call_original
    allow(described_class).to receive(:render_single_annotation).with(
      anything, anything, hash_including('uuid' => pen_annotation['uuid']), anything, anything, anything, anything
    ).and_raise(StandardError, 'Simulated canvas crash')
    allow(Rails.logger).to receive(:warn)

    described_class.call(
      doc: hexapdf_doc,
      attachment_uuid: attachment_uuid,
      annotations: [pen_annotation, text_annotation]
    )

    expect(Rails.logger).to have_received(:warn).with(/Failed to render annotation #{pen_annotation['uuid']}/)
    out = StringIO.new
    expect { hexapdf_doc.write(out) }.not_to raise_error
  end
end
