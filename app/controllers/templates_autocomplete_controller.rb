# frozen_string_literal: true

class TemplatesAutocompleteController < ApplicationController
  skip_authorization_check only: :index

  # rubocop:disable Metrics/AbcSize -- Existing complex method
  def index
    templates = Template
                .accessible_by(current_ability)
                .active
                .includes(:author, :departments)
                .order(created_at: :desc)

    if params[:q].present?
      keyword = params[:q].to_s.downcase

      templates = templates.to_a.select do |template|
        searchable_values = [
          template.name,
          template.author&.first_name,
          template.author&.last_name,
          template.author&.full_name,
          template.author&.email,
          *template.departments.map(&:name)
        ]

        searchable_values.compact.any? { |value| value.downcase.include?(keyword) }
      end
    else
      templates = templates.limit(8).to_a
    end

    render json: templates.first(8).map { |template|
      {
        id: template.id,
        name: template.name,
        author: template.author&.full_name.presence || template.author&.email.to_s,
        departments: template.departments.map(&:name).sort,
        url: template_path(template)
      }
    }
  end
  # rubocop:enable Metrics/AbcSize
end
