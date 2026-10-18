# frozen_string_literal: true

module TemplateAnnotations
  SUPPORTED_TYPES = %w[pen highlighter text].freeze
  HEX_COLOR_REGEXP = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/
  RGBA_COLOR_REGEXP = /\Argba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(?:,\s*[\d.]+\s*)?\)\z/i
  UUID_REGEXP = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/

  DEFAULT_COLOR = '#1e293b'
  DEFAULT_PEN_WIDTH = 0.003
  DEFAULT_HIGHLIGHTER_WIDTH = 0.025
  DEFAULT_HIGHLIGHTER_OPACITY = 0.35
  DEFAULT_TEXT_FONT_SIZE = 14
  MAX_POINTS_COUNT = 5000
  MAX_TEXT_LENGTH = 2000
  MAX_ANNOTATIONS_COUNT = 1000

  module_function

  def normalize(raw_annotations)
    return [] unless raw_annotations.is_a?(Array)

    raw_annotations.take(MAX_ANNOTATIONS_COUNT).filter_map do |annot|
      normalize_annotation(annot)
    end
  end

  def normalize_annotation(annot)
    annot = annot.to_unsafe_h if annot.respond_to?(:to_unsafe_h)
    return nil unless annot.is_a?(Hash)

    type = annot['type'].to_s.downcase.strip
    return nil unless SUPPORTED_TYPES.include?(type)

    uuid = annot['uuid'].to_s.strip
    uuid = SecureRandom.uuid unless uuid.match?(UUID_REGEXP)

    attachment_uuid = annot['attachment_uuid'].to_s.strip
    return nil if attachment_uuid.blank?

    page = extract_page_index(annot['page'])
    return nil unless page

    color = normalize_color(annot['color'])

    case type
    when 'pen'
      points = normalize_points(annot['points'])
      points ? normalize_pen_stroke(annot, uuid:, attachment_uuid:, page:, color:, points:) : nil
    when 'highlighter'
      points = normalize_points(annot['points'])
      points ? normalize_highlighter_stroke(annot, uuid:, attachment_uuid:, page:, color:, points:) : nil
    when 'text'
      normalize_text(annot, uuid:, attachment_uuid:, page:, color:)
    end
  end

  def extract_page_index(raw_page)
    return nil if raw_page.nil? || (raw_page.is_a?(String) && !raw_page.strip.match?(/\A\d+\z/))

    page = raw_page.to_i
    page.negative? || page > 5000 ? nil : page
  end

  def normalize_color(color_str)
    str = color_str.to_s.strip
    return str if str.match?(HEX_COLOR_REGEXP)
    return str if str.match?(RGBA_COLOR_REGEXP)

    DEFAULT_COLOR
  end

  def normalize_points(raw_points)
    return nil unless raw_points.is_a?(Array) && raw_points.size >= 2

    points = raw_points.take(MAX_POINTS_COUNT).filter_map do |pt|
      pt = pt.to_unsafe_h if pt.respond_to?(:to_unsafe_h)
      next unless pt.is_a?(Hash)

      x = pt['x'].to_f
      y = pt['y'].to_f
      next unless x.finite? && y.finite?

      {
        'x' => x.clamp(0.0, 1.0).round(5),
        'y' => y.clamp(0.0, 1.0).round(5)
      }
    end

    points.size >= 2 ? points : nil
  end

  def normalize_pen_stroke(annot, uuid:, attachment_uuid:, page:, color:, points:)
    raw_width = annot['width'].to_f
    width = raw_width.positive? && raw_width.finite? ? raw_width.clamp(0.0005, 0.05).round(5) : DEFAULT_PEN_WIDTH

    {
      'uuid' => uuid,
      'type' => 'pen',
      'attachment_uuid' => attachment_uuid,
      'page' => page,
      'color' => color,
      'width' => width,
      'points' => points
    }
  end

  def normalize_highlighter_stroke(annot, uuid:, attachment_uuid:, page:, color:, points:)
    raw_width = annot['width'].to_f
    width = raw_width.positive? && raw_width.finite? ? raw_width.clamp(0.005, 0.1).round(5) : DEFAULT_HIGHLIGHTER_WIDTH
    raw_opacity = annot['opacity'].to_f
    opacity = if raw_opacity.positive? && raw_opacity.finite?
                raw_opacity.clamp(0.05, 1.0).round(2)
              else
                DEFAULT_HIGHLIGHTER_OPACITY
              end

    {
      'uuid' => uuid,
      'type' => 'highlighter',
      'attachment_uuid' => attachment_uuid,
      'page' => page,
      'color' => color,
      'width' => width,
      'opacity' => opacity,
      'points' => points
    }
  end

  def normalize_text(annot, uuid:, attachment_uuid:, page:, color:)
    text = annot['text'].to_s.strip.slice(0, MAX_TEXT_LENGTH)
    return nil if text.blank?

    x = parse_finite_coordinate(annot['x'])
    y = parse_finite_coordinate(annot['y'])
    return nil unless x && y

    w = parse_finite_dimension(annot['w'], [1.0 - x, 0.01].max, 0.2)
    h = parse_finite_dimension(annot['h'], [1.0 - y, 0.01].max, 0.05)
    font_size = normalize_font_size(annot['font_size'])

    {
      'uuid' => uuid,
      'type' => 'text',
      'attachment_uuid' => attachment_uuid,
      'page' => page,
      'x' => x,
      'y' => y,
      'w' => w,
      'h' => h,
      'text' => text,
      'color' => color,
      'font_size' => font_size
    }
  end

  def parse_finite_coordinate(val)
    return nil if val.nil?
    return nil if val.is_a?(String) && val.strip.match?(/\A[-+]?(?:nan|infinity|inf)\z/i)

    f = val.to_f
    f.finite? ? f.clamp(0.0, 1.0).round(5) : nil
  end

  def parse_finite_dimension(val, max_limit, default_val)
    return default_val if val.nil?
    return default_val if val.is_a?(String) && val.strip.match?(/\A[-+]?(?:nan|infinity|inf)\z/i)

    f = val.to_f
    f.positive? && f.finite? ? f.clamp(0.01, max_limit).round(5) : [default_val, max_limit].min
  end

  def normalize_font_size(raw_size)
    f = raw_size.to_f
    f.positive? && f.finite? ? f.clamp(6.0, 72.0).round(1) : DEFAULT_TEXT_FONT_SIZE
  end

  def clean_orphaned(target, valid_uuids = nil)
    if target.respond_to?(:schema) && target.respond_to?(:preferences)
      return unless target.preferences.is_a?(Hash) && target.preferences['annotations'].is_a?(Array)

      uuids = target.schema.pluck('attachment_uuid').compact
      target.preferences['annotations'] = clean_orphaned(target.preferences['annotations'], uuids)
    else
      annotations = Array.wrap(target)
      uuids = Array.wrap(valid_uuids)
      annotations.select do |annot|
        annot.is_a?(Hash) && uuids.include?(annot['attachment_uuid'])
      end
    end
  end

  def remap_attachments(annotations, replacements)
    return [] unless annotations.is_a?(Array) && replacements.is_a?(Hash)

    annotations.filter_map do |annot|
      next unless annot.is_a?(Hash)

      old_att_uuid = annot['attachment_uuid']
      new_att_uuid = replacements[old_att_uuid]
      next unless new_att_uuid

      copied = annot.deep_dup
      copied['uuid'] = SecureRandom.uuid
      copied['attachment_uuid'] = new_att_uuid
      copied
    end
  end
end
