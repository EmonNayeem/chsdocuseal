# frozen_string_literal: true

if defined?(LetterOpenerWeb)
  require 'rexml/document'

  module LetterOpenerWebXmlCompatibility
    private

    def remove_attachments_link(headers)
      sanitized = headers.gsub(/&(?!(?:#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z0-9]+);)/, '&amp;')
      xml = REXML::Document.new(sanitized)
      label_element = xml.root.elements.find { |e| e.get_text&.value&.match?(/attachments:/i) }

      if label_element
        xml.root.delete_element(label_element.next_element)
        xml.root.delete_element(label_element)
      end

      xml.to_s
    rescue REXML::ParseException
      headers.sub(%r{<dt>\s*Attachments:\s*</dt>\s*<dd>.*?</dd>}mi, '')
    end

    def adjust_link_targets(contents)
      contents.scan(%r{<a\s[^>]+>(?:.|\s)*?</a>}).each do |link|
        fixed_link = fix_link_html(link)
        sanitized_link = fixed_link.gsub(/&(?!(?:#[0-9]+|#x[0-9a-fA-F]+|[a-zA-Z0-9]+);)/, '&amp;')
        begin
          xml = REXML::Document.new(sanitized_link).root
          next if xml.nil?
          next if xml.attributes['href']&.match?(/(?:plain|rich)\.html/)

          xml.attributes['target'] = '_blank'
          xml.add_text('') unless xml.text
          contents.gsub!(link, xml.to_s)
        rescue REXML::ParseException
          next
        end
      end
      contents
    end
  end

  Rails.application.config.to_prepare do
    LetterOpenerWeb::Letter.prepend(LetterOpenerWebXmlCompatibility)
  end
end
