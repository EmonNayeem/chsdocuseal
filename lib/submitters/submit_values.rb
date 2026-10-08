# frozen_string_literal: true

module Submitters
  module SubmitValues
    ValidationError = Class.new(StandardError)
    RequiredFieldError = Class.new(StandardError)

    VARIABLE_REGEXP = /\{\{?(\w+)\}\}?/
    PHONE_REGEXP = /[+\d()\s-]+/
    NONEDITABLE_FIELD_TYPES = %w[stamp heading strikethrough].freeze

    STRFTIME_MAP = {
      'hour' => '%-k',
      'minute' => '%M',
      'day' => '%-d',
      'month' => '%-m',
      'year' => '%Y'
    }.freeze

    module_function

    def call(submitter, params, request, validate_required: true)
      Submissions.update_template_fields!(submitter.submission) if submitter.submission.template_fields.blank?

      unless submitter.submission_events.exists?(event_type: 'start_form')
        SubmissionEvents.create_with_tracking_data(submitter, 'start_form', request)

        WebhookUrls.enqueue_events(submitter, 'form.started')
      end

      update_submitter!(submitter, params, request, validate_required:)

      submitter.submission.save!

      if submitter.completed_at?
        is_last = Submissions.maybe_update_completed_at(submitter.submission)

        ProcessSubmitterCompletionJob.perform_async('submitter_id' => submitter.id, 'is_last' => is_last)
      end

      submitter
    end

    def update_submitter!(submitter, params, request, validate_required: true)
      values = normalized_values(params)

      submitter.values.merge!(values)
      submitter.opened_at ||= Time.current

      assign_completed_attributes(submitter, request, validate_required:) if params[:completed] == 'true'

      ApplicationRecord.transaction do
        reason_field = maybe_set_signature_reason!(values, submitter, params)
        validate_values!(reason_field ? values.except(reason_field['uuid']) : values, submitter, params, request)

        if (touch_attachment_uuid = params[:touch_attachment_uuid].presence)
          ActiveStorage::Attachment.where(uuid: touch_attachment_uuid, record: submitter).touch_all(:created_at)
        end

        if params[:completed] == 'true'
          maybe_invite_via_field(submitter, request)

          SubmissionEvents.create_with_tracking_data(submitter, 'complete_form', request)
        end

        submitter.save!
      end

      SearchEntries.enqueue_reindex(submitter) if submitter.completed_at?

      submitter
    end

    def assign_completed_attributes(submitter, request, validate_required: true)
      submitter.completed_at = Time.current
      submitter.ip = request.remote_ip
      submitter.ua = request.user_agent
      submitter.timezone = request.params[:timezone]

      submitter.values = merge_default_values(submitter)

      required_field_uuids_acc = Set.new

      submitter.values = maybe_remove_condition_values(submitter, required_field_uuids_acc:)

      formula_values = build_formula_values(submitter)

      if formula_values.present?
        submitter.values = submitter.values.merge(formula_values)
        submitter.values = maybe_remove_condition_values(submitter, required_field_uuids_acc:)
      end

      submitter.values = replace_current_date_placeholders(submitter)

      required_field_uuids_acc.each do |uuid|
        next if submitter.values[uuid].present?

        raise RequiredFieldError, uuid if validate_required

        Rollbar.warning("Required field #{submitter.id}: #{uuid}") if defined?(Rollbar)
      end

      submitter
    end

    def maybe_set_signature_reason!(values, submitter, params)
      return if params[:with_reason].blank?

      reason_field_uuid = params[:with_reason]
      signature_field_uuid = values.except(reason_field_uuid).keys.first

      signature_field = submitter.submission.template_fields.find do |e|
        e['uuid'] == signature_field_uuid && e['submitter_uuid'] == submitter.uuid
      end

      reason_field = submitter.submission.template_fields.find do |e|
        e['uuid'] == reason_field_uuid && e['submitter_uuid'] == submitter.uuid
      end

      if reason_field
        if reason_field.dig('preferences', 'signature_field_uuid') != signature_field['uuid']
          raise ValidationError, 'Invalid field'
        end
      else
        reason_field = { 'type' => 'text',
                         'uuid' => reason_field_uuid,
                         'name' => I18n.t(:reason),
                         'readonly' => true,
                         'preferences' => { 'signature_field_uuid' => signature_field['uuid'] },
                         'submitter_uuid' => submitter.uuid }

        submitter.submission.template_fields.insert(submitter.submission.template_fields.index(signature_field) + 1,
                                                    reason_field)
      end

      signature_field['preferences'] ||= {}
      signature_field['preferences']['reason_field_uuid'] = reason_field_uuid

      submitter.submission.save!

      reason_field
    end

    def normalized_values(params)
      params.fetch(:values, {}).to_unsafe_h.transform_values do |v|
        if params[:cast_boolean] == 'true'
          v == 'true'
        elsif params[:cast_number] == 'true'
          if v == ''
            nil
          else
            (v.to_f % 1).zero? ? v.to_i : v.to_f
          end
        elsif params[:normalize_phone] == 'true'
          v.to_s.gsub(/[^0-9+]/, '')
        else
          v.is_a?(Array) ? v.compact_blank : v
        end
      end
    end

    def validate_values!(values, submitter, params, request)
      values.each do |key, value|
        field = submitter.submission.template_fields.find { |e| e['uuid'] == key }

        validate_value!(value, field, params, submitter, request)
      end
    end

    def merge_default_values(submitter, with_verification: true)
      default_values = submitter.submission.template_fields.each_with_object({}) do |field, acc|
        next if field['submitter_uuid'] != submitter.uuid

        if field['type'] == 'stamp'
          acc[field['uuid']] ||=
            Submitters::CreateStampAttachment.build_attachment(
              submitter,
              with_logo: field.dig('preferences', 'with_logo') != false
            ).uuid

          next
        end

        if field['type'] == 'verification' && with_verification
          acc[field['uuid']] =
            if submitter.submission_events.exists?(event_type: :complete_verification)
              I18n.t(:verified, locale: :en)
            elsif field['required']
              raise ValidationError, 'ID Not Verified'
            end

          next
        end

        value = field['default_value']

        next if value.blank?

        acc[field['uuid']] = template_default_value_for_submitter(value, submitter, field:, with_time: true)
      end

      default_values.compact_blank.merge(submitter.values)
    end

    def build_formula_values(submitter)
      submission_values = nil

      computed_values = submitter.submission.template_fields.each_with_object({}) do |field, acc|
        next if field['submitter_uuid'] != submitter.uuid
        next if field['type'] == 'payment'

        formula = field.dig('preferences', 'formula')

        next if formula.blank?

        submission_values ||=
          if submitter.submission.template_submitters.size > 1
            merge_submitters_values(submitter)
          else
            submitter.values
          end

        formula = normalize_formula(formula, submitter.submission, submission_values:)

        acc[field['uuid']] = calculate_formula_value(formula, submission_values.merge(acc.compact_blank))
      end

      computed_values.compact_blank
    end

    def normalize_formula(formula, submission, depth: 0, submission_values: nil)
      raise ValidationError, 'Formula infinite loop' if depth > 10

      formula.gsub(/{{(.*?)}}/) do |match|
        uuid = Regexp.last_match(1)

        if (nested_formula = submission.fields_uuid_index.dig(uuid, 'preferences', 'formula').presence)
          if check_field_conditions(submission_values, submission.fields_uuid_index[uuid], submission.fields_uuid_index)
            "(#{normalize_formula(nested_formula, submission, depth: depth + 1, submission_values:)})"
          else
            '0'
          end
        else
          match
        end
      end
    end

    def calculate_formula_value(_formula, _values)
      0
    end

    def replace_current_date_placeholders(submitter)
      submitter.values.each_with_object({}) do |(uuid, v), acc|
        acc[uuid] =
          if v == '{{date}}'
            field = submitter.submission.fields_uuid_index[uuid]

            TimeUtils.current_date_value(field&.dig('preferences', 'format'), submitter.account.timezone)
          else
            v
          end
      end
    end

    def template_default_value_for_submitter(value, submitter, with_time: false, field: nil)
      return if value.blank?
      return if submitter.blank?

      role = submitter.submission.template_submitters.find { |e| e['uuid'] == submitter.uuid }['name']

      replace_default_variables(value,
                                submitter.attributes.merge('role' => role),
                                submitter.submission,
                                with_time:,
                                field:)
    end

    def maybe_remove_condition_values(submitter, required_field_uuids_acc: nil)
      submission = submitter.submission

      submitters_values = nil
      has_other_submitters = submission.template_submitters.size > 1

      has_document_conditions = submission_has_document_conditions?(submission)

      attachments_index =
        if has_document_conditions
          submitters_values = merge_submitters_values(submitter)

          Submissions.filtered_conditions_schema(submission, values: submitters_values)
                     .index_by { |i| i['attachment_uuid'] }
        end

      submission.template_fields.each do |field|
        next if field['submitter_uuid'] != submitter.uuid

        required_field_uuids_acc.add(field['uuid']) if required_field_uuids_acc && required_editable_field?(field)

        if has_document_conditions && !check_field_areas_attachments(field, attachments_index)
          delete_field_value!(field, submitter, submitters_values, required_field_uuids_acc)
        end

        if has_other_submitters && !submitters_values &&
           field_conditions_other_submitter?(submitter, field, submission.fields_uuid_index)
          submitters_values = merge_submitters_values(submitter)
        end

        unless check_field_conditions(submitters_values || submitter.values, field, submission.fields_uuid_index)
          delete_field_value!(field, submitter, submitters_values, required_field_uuids_acc)
        end
      end

      submitter.values
    end

    def delete_field_value!(field, submitter, submitters_values = nil, required_field_uuids_acc = nil)
      submitter.values.delete(field['uuid'])
      submitters_values&.delete(field['uuid'])
      required_field_uuids_acc&.delete(field['uuid'])
    end

    def submission_has_document_conditions?(submission)
      (submission.template_schema || submission.template.schema).any? { |e| e['conditions'].present? }
    end

    def required_editable_field?(field)
      return false if NONEDITABLE_FIELD_TYPES.include?(field['type'])

      field['required'].present? && field['readonly'].blank?
    end

    def check_field_areas_attachments(field, attachments_index)
      return true if field['areas'].blank?

      field['areas'].any? { |area| attachments_index[area['attachment_uuid']] }
    end

    def merge_submitters_values(submitter)
      submitter.submission.submitters
               .reject { |sub| sub.uuid == submitter.uuid }
               .reduce({}) { |acc, sub| acc.merge(sub.values) }
               .merge(submitter.values)
    end

    def field_conditions_other_submitter?(submitter, field, fields_uuid_index)
      return false if field['conditions'].blank?

      field['conditions'].to_a.any? do |c|
        fields_uuid_index.dig(c['field_uuid'], 'submitter_uuid') != submitter.uuid
      end
    end

    def check_field_conditions(submitter_values, field, fields_uuid_index, visited = Set.new)
      return true if field['conditions'].blank?

      return false if visited.include?(field['uuid'])

      visited.add(field['uuid'])

      result = field['conditions'].each_with_object([]) do |c, acc|
        source_field = fields_uuid_index[c['field_uuid']]

        is_satisfied = true
        if !source_field
          is_satisfied = false
        elsif !check_field_conditions(submitter_values, source_field, fields_uuid_index, visited.dup)
          is_multiple = source_field['type'] == 'multiple' || source_field.dig('preferences', 'allow_multiple_values')
          empty_value = is_multiple ? [] : nil
          is_satisfied = check_field_condition(c, empty_value, fields_uuid_index)
        else
          is_satisfied = check_field_condition(c, submitter_values[c['field_uuid']], fields_uuid_index)
        end

        if c['operation'] == 'or'
          acc.push(acc.pop || is_satisfied)
        else
          acc.push(is_satisfied)
        end
      end.exclude?(false)

      visited.delete(field['uuid'])

      result
    end

    # rubocop:disable Metrics
    def check_field_condition(condition, value, fields_uuid_index)
      field = fields_uuid_index[condition['field_uuid']]

      case condition['action']
      when 'empty', 'unchecked'
        value.blank?
      when 'not_empty', 'checked'
        value.present?
      when lambda do |action|
             action.in?(%w[equal not_equal greater_than greater_than_or_equal less_than less_than_or_equal]) &&
               field&.dig('type') == 'number'
           end
        return false if value.blank? || condition['value'].blank?

        actual = value.to_f
        expected = condition['value'].to_f

        case condition['action']
        when 'equal' then (actual - expected).abs < Float::EPSILON
        when 'not_equal' then (actual - expected).abs > Float::EPSILON
        when 'greater_than' then actual > expected
        when 'greater_than_or_equal' then actual >= expected
        when 'less_than' then actual < expected
        when 'less_than_or_equal' then actual <= expected
        else false
        end
      when 'equal', 'not_equal', 'contains', 'does_not_contain', 'starts_with', 'ends_with'
        return true unless field

        expected_str = condition['value'].to_s.strip.downcase

        if field['options']
          option_index = field['options'].index { |o| o['uuid'] == condition['value'] }
          if option_index
            option = field['options'][option_index]
            fallback = "#{I18n.t('option', locale: :en)} #{option_index + 1}"
            expected_str = (option['value'].presence || fallback).to_s.strip.downcase
          end
        end

        if field['type'] == 'date' && %w[equal not_equal].include?(condition['action'])
          actual_str = value.to_s.strip.downcase
          return condition['action'] == 'equal' ? actual_str == expected_str : actual_str != expected_str
        end

        values = Array.wrap(value).map { |v| v.to_s.strip.downcase }

        case condition['action']
        when 'equal' then values.any?(expected_str)
        when 'not_equal' then values.none?(expected_str)
        when 'contains' then values.any? { |v| v.include?(expected_str) }
        when 'does_not_contain' then values.all? { |v| v.exclude?(expected_str) }
        when 'starts_with' then values.any? { |v| v.start_with?(expected_str) }
        when 'ends_with' then values.any? { |v| v.end_with?(expected_str) }
        else false
        end
      else
        true
      end
    end
    # rubocop:enable Metrics

    def replace_default_variables(value, attrs, submission, with_time: false, field: nil)
      return value if value.in?([true, false]) || value.is_a?(Numeric) || value.is_a?(Array)
      return if value.blank?

      value.to_s.gsub(VARIABLE_REGEXP) do |e|
        case key = ::Regexp.last_match(1)
        when 'id'
          attrs['submission_id']
        when 'time'
          if with_time
            I18n.l(Time.current.in_time_zone(submission.account.timezone),
                   format: :long, locale: submission.account.locale)
          else
            e
          end
        when 'hour', 'minute', 'day', 'month', 'year'
          with_time ? Time.current.in_time_zone(submission.account.timezone).strftime(STRFTIME_MAP[key]) : e
        when 'date'
          with_time ? TimeUtils.current_date_value(field&.dig('preferences', 'format'), submission.account.timezone) : e
        when 'role', 'email', 'phone', 'name'
          attrs[key] || e
        else
          e
        end
      end
    end

    def maybe_invite_via_field(submitter, request)
      submission = submitter.submission

      is_invited = false

      submission.template_submitters.each do |s|
        field_uuid = s['invite_via_field_uuid']

        next if field_uuid.blank?

        field = submission.template_fields.find { |e| e['uuid'] == field_uuid }

        next unless field
        next unless field['submitter_uuid'] == submitter.uuid

        next if submission.submitters.exists?(uuid: s['uuid'])

        value = submitter.values[field_uuid]

        next if value.blank?

        if value.include?('@')
          email = Submissions.normalize_email(value)
        elsif value.match?(PHONE_REGEXP)
          phone = value.gsub(/[^+\d]/, '')
        end

        next if email.blank? && phone.blank?

        submission.submitters.create!(uuid: s['uuid'], email:, phone:, account_id: submitter.account_id)

        SubmissionEvents.create_with_tracking_data(submitter, 'invite_party', request, { uuid: submitter.uuid })

        is_invited = true
      end

      submission.update!(submitters_order: :preserved) if is_invited

      submitter
    end

    def validate_value!(_value, field, _params, submitter, _request)
      raise ValidationError, 'Missing field' unless field
      raise ValidationError, 'Invalid field' if field['submitter_uuid'] != submitter.uuid

      if field['readonly'] == true
        Rollbar.warning("Readonly field #{submitter.id}: #{field['uuid']}") if defined?(Rollbar)

        raise ValidationError, 'Read-only field'
      end

      true
    end
  end
end
