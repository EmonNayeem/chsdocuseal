# frozen_string_literal: true

class TemplatesPrefillableFieldsController < ApplicationController
  PREFILLABLE_FIELD_TYPES = %w[text number cells date checkbox select radio phone].freeze

  load_and_authorize_resource :template

  def create
    authorize!(:update, @template)

    field = @template.fields.find { |f| f['uuid'] == params[:field_uuid] }

    if params[:prefillable] == 'false'
      field.delete('prefillable')
      field.delete('readonly')
      field.delete('recipient_mapping')
    elsif params[:prefillable] == 'true'
      field['prefillable'] = true
      field['readonly'] = true

      allowed_mappings = %w[name email phone job_title department]
      if params[:recipient_mapping].present? && params[:recipient_mapping].in?(allowed_mappings)
        field['recipient_mapping'] = params[:recipient_mapping]
      elsif params.key?(:recipient_mapping)
        field.delete('recipient_mapping')
      end
    end

    @template.save!

    render turbo_stream: turbo_stream.replace(:prefillable_fields_list, partial: 'list',
                                                                        locals: { template: @template })
  end
end
