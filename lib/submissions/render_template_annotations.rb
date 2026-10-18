# frozen_string_literal: true

module Submissions
  module RenderTemplateAnnotations
    module_function

    def call(submission_or_doc = nil, pdfs_index = nil, doc: nil, attachment_uuid: nil, annotations: nil)
      if doc && attachment_uuid && annotations
        normalized = annotations.is_a?(Array) ? TemplateAnnotations.normalize(annotations) : []
        filtered = normalized.select { |a| a['attachment_uuid'] == attachment_uuid }
        render_document_annotations(doc, filtered)
      elsif submission_or_doc.is_a?(HexaPDF::Document) && pdfs_index.is_a?(Array)
        render_document_annotations(submission_or_doc, TemplateAnnotations.normalize(pdfs_index))
      else
        submission = submission_or_doc
        return if submission.blank? || pdfs_index.blank?

        annots = extract_annotations(submission)
        return if annots.blank?

        annotations_by_doc = annots.group_by { |a| a['attachment_uuid'] }

        annotations_by_doc.each do |att_uuid, doc_annots|
          pdf = pdfs_index[att_uuid]
          next unless pdf

          render_document_annotations(pdf, doc_annots)
        end
      end
    end

    def extract_annotations(submission)
      return [] if submission.blank?

      annots = submission.preferences.is_a?(Hash) ? submission.preferences['annotations'] : nil
      return TemplateAnnotations.normalize(annots) if annots.is_a?(Array)

      []
    end

    def render_document_annotations(pdf, annotations)
      if defined?(Submissions::GenerateResultAttachments) &&
         Submissions::GenerateResultAttachments.respond_to?(:on_missing_glyph)
        pdf.config['font.on_missing_glyph'] ||= Submissions::GenerateResultAttachments.method(:on_missing_glyph).to_proc
      end

      annots_by_page = annotations.group_by { |a| a['page'].to_i }

      annots_by_page.each do |page_index, page_annots|
        pdf_page = pdf.pages[page_index]
        next unless pdf_page

        render_page_annotations(pdf, pdf_page, page_annots)
      end
    end

    def render_page_annotations(pdf, page, annotations)
      page.rotate(0, flatten: true) if page[:Rotate] != 0

      box = page.box
      origin_x = box.left.to_f
      origin_y = box.bottom.to_f
      page_w = box.width.to_f
      page_h = box.height.to_f
      canvas = page.canvas(type: :overlay)

      annotations.each do |annot|
        render_single_annotation(pdf, canvas, annot, origin_x, origin_y, page_w, page_h)
      rescue StandardError => e
        Rails.logger.warn("Failed to render annotation #{annot['uuid']}: #{e.message}")
        Rollbar.error(e, annotation_uuid: annot['uuid']) if defined?(Rollbar)
      end
    end

    def render_single_annotation(pdf, canvas, annot, origin_x, origin_y, page_w, page_h)
      case annot['type']
      when 'pen'
        render_pen(canvas, annot, origin_x, origin_y, page_w, page_h)
      when 'highlighter'
        render_highlighter(canvas, annot, origin_x, origin_y, page_w, page_h)
      when 'text'
        render_text(pdf, canvas, annot, origin_x, origin_y, page_w, page_h)
      end
    end

    def render_pen(canvas, annot, origin_x, origin_y, page_w, page_h)
      points = annot['points']
      return if points.blank? || points.size < 2

      r, g, b = parse_hex_color(annot['color'])
      line_w = [annot['width'].to_f * page_w, 0.5].max

      canvas.save_graphics_state
      begin
        canvas.stroke_color(r, g, b)
        canvas.line_width(line_w)
        canvas.line_cap_style(:round)
        canvas.line_join_style(:round)

        first_pt = points.first
        canvas.move_to(origin_x + (first_pt['x'] * page_w), origin_y + ((1.0 - first_pt['y']) * page_h))

        points.drop(1).each do |pt|
          canvas.line_to(origin_x + (pt['x'] * page_w), origin_y + ((1.0 - pt['y']) * page_h))
        end

        canvas.stroke
      ensure
        canvas.restore_graphics_state
      end
    end

    def render_highlighter(canvas, annot, origin_x, origin_y, page_w, page_h)
      points = annot['points']
      return if points.blank? || points.size < 2

      r, g, b = parse_hex_color(annot['color'])
      opacity = (annot['opacity'] || TemplateAnnotations::DEFAULT_HIGHLIGHTER_OPACITY).to_f.clamp(0.05, 1.0)
      line_w = [annot['width'].to_f * page_w, 2.0].max

      canvas.save_graphics_state
      begin
        canvas.opacity(stroke_alpha: opacity, fill_alpha: opacity)
        canvas.stroke_color(r, g, b)
        canvas.line_width(line_w)
        canvas.line_cap_style(:round)
        canvas.line_join_style(:round)

        first_pt = points.first
        canvas.move_to(origin_x + (first_pt['x'] * page_w), origin_y + ((1.0 - first_pt['y']) * page_h))

        points.drop(1).each do |pt|
          canvas.line_to(origin_x + (pt['x'] * page_w), origin_y + ((1.0 - pt['y']) * page_h))
        end

        canvas.stroke
      ensure
        canvas.restore_graphics_state
      end
    end

    def render_text(pdf, canvas, annot, origin_x, origin_y, page_w, page_h)
      text = annot['text'].to_s
      return if text.blank?

      r, g, b = parse_hex_color(annot['color'])
      raw_pt = annot['font_size'].to_f
      font_size = (raw_pt.positive? ? raw_pt * (page_w / 612.0) : 14.0).clamp(4.0, 144.0)
      font = pdf.fonts.add(Submissions::GenerateResultAttachments::FONT_NAME)

      x = origin_x + (annot['x'].to_f * page_w)
      top_y = origin_y + ((1.0 - annot['y'].to_f) * page_h)
      baseline_y = top_y - font_size
      line_height = font_size * 1.25

      canvas.save_graphics_state
      begin
        canvas.font(font, size: font_size)
        canvas.fill_color(r, g, b)

        text.split("\n").each_with_index do |line, idx|
          current_y = baseline_y - (idx * line_height)
          next if current_y < origin_y - font_size

          draw_text_line_safely(canvas, line, x, current_y)
        end
      ensure
        canvas.restore_graphics_state
      end
    end

    def draw_text_line_safely(canvas, line, x_pos, y_pos)
      canvas.text(line, at: [x_pos, y_pos])
    rescue HexaPDF::MissingGlyphError => e
      msg = begin
        e.message
      rescue StandardError
        e.class.name
      end
      Rails.logger.warn("RenderTemplateAnnotations missing glyph: #{msg}")
      safe_line = line.encode('ASCII', invalid: :replace, undef: :replace, replace: '?')
      canvas.text(safe_line, at: [x_pos, y_pos])
    rescue StandardError => e
      msg = begin
        e.message
      rescue StandardError
        e.class.name
      end
      Rails.logger.warn("RenderTemplateAnnotations text draw error: #{msg}")
      Rollbar.error(e) if defined?(Rollbar)
    end

    def parse_hex_color(hex_str)
      clean = hex_str.to_s.delete_prefix('#')
      case clean.length
      when 3
        r = clean[0].hex * 17
        g = clean[1].hex * 17
        b = clean[2].hex * 17
      when 6, 8
        r = clean[0..1].hex
        g = clean[2..3].hex
        b = clean[4..5].hex
      else
        return [0.0, 0.0, 0.0]
      end

      [(r / 255.0).round(4), (g / 255.0).round(4), (b / 255.0).round(4)]
    end
  end
end
