# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submitters::SubmitValues do
  describe '.call' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account:) }

    let(:template) do
      create(
        :template,
        account:,
        author: user,
        only_field_types: ['select']
      )
    end

    let(:submission) do
      create(
        :submission,
        :with_submitters,
        template:,
        created_by_user: user
      )
    end

    let(:submitter) { submission.submitters.first }

    let(:select_field) do
      submission.template_fields.find { |field| field['type'] == 'select' }
    end

    let(:warden) do
      instance_double(Warden::Proxy).tap do |w|
        allow(w).to receive(:user).with(:user).and_return(nil)
      end
    end

    let(:session) do
      instance_double(ActionDispatch::Request::Session, id: 'test-session')
    end

    let(:request) do
      instance_double(
        ActionDispatch::Request,
        remote_ip: '127.0.0.1',
        user_agent: 'rspec',
        session:,
        env: { 'warden' => warden },
        params: {}
      )
    end

    it 'accepts scalar value for select field' do
      expect(select_field['submitter_uuid']).to eq(submitter.uuid)

      params = ActionController::Parameters.new(
        values: {
          select_field['uuid'] => 'HR'
        }
      )

      described_class.call(
        submitter,
        params,
        request,
        validate_required: false
      )

      expect(submitter.reload.values[select_field['uuid']]).to eq('HR')
    end

    it 'accepts array value for select field' do
      expect(select_field['submitter_uuid']).to eq(submitter.uuid)

      params = ActionController::Parameters.new(
        values: {
          select_field['uuid'] => [
            'Accounts',
            'Admin',
            'QHSE',
            'Custom Value'
          ]
        }
      )

      described_class.call(
        submitter,
        params,
        request,
        validate_required: false
      )

      expect(submitter.reload.values[select_field['uuid']]).to eq(
        [
          'Accounts',
          'Admin',
          'QHSE',
          'Custom Value'
        ]
      )
    end

    context 'with conditions' do
      let(:template) do
        create(
          :template,
          account:,
          author: user,
          only_field_types: %w[select text number multiple]
        )
      end

      let(:text_field) { submission.template_fields.find { |f| f['type'] == 'text' } }
      let(:number_field) { submission.template_fields.find { |f| f['type'] == 'number' } }
      let(:multiple_field) { submission.template_fields.find { |f| f['type'] == 'multiple' } }
      let(:select_field) { submission.template_fields.find { |f| f['type'] == 'select' } }

      it '1. TEXT EQUAL: evaluates text equal case-insensitively and trimmed' do
        number_field['conditions'] = [{
          'field_uuid' => text_field['uuid'],
          'action' => 'equal',
          'value' => 'hr'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            text_field['uuid'] => ' HR ',
            number_field['uuid'] => 123
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[number_field['uuid']]).to eq(123)
      end

      it '2. TEXT CONTAINS: evaluates text contains' do
        number_field['conditions'] = [{
          'field_uuid' => text_field['uuid'],
          'action' => 'contains',
          'value' => 'developer'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            text_field['uuid'] => 'Senior Developer',
            number_field['uuid'] => 123
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[number_field['uuid']]).to eq(123)
      end

      it '3. NUMBER GREATER THAN OR EQUAL: evaluates number comparisons correctly' do
        text_field['conditions'] = [{
          'field_uuid' => number_field['uuid'],
          'action' => 'greater_than_or_equal',
          'value' => '1000'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        # 1000 >= 1000 is true
        params = ActionController::Parameters.new(
          values: {
            number_field['uuid'] => 1000,
            text_field['uuid'] => 'Some value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Some value')

        # 999 >= 1000 is false
        params = ActionController::Parameters.new(
          values: {
            number_field['uuid'] => 999,
            text_field['uuid'] => 'Some value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to be_nil
      end

      it '4. CHECKBOX GROUP CONTAINS: evaluates checkbox group contains with UUID resolution' do
        multiple_field['options'] = [
          { 'uuid' => 'opt_acc', 'value' => 'Accounts' },
          { 'uuid' => 'opt_adm', 'value' => 'Admin' },
          { 'uuid' => 'opt_ict', 'value' => 'ICT' },
          { 'uuid' => 'opt_qhse', 'value' => 'QHSE' }
        ]
        text_field['conditions'] = [{
          'field_uuid' => multiple_field['uuid'],
          'action' => 'contains',
          'value' => 'opt_ict'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            multiple_field['uuid'] => %w[Accounts ICT],
            text_field['uuid'] => 'Some value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Some value')
      end

      it '5. FEATURE #7 MULTI SELECT - PREDEFINED: evaluates multi select contains with predefined option UUID' do
        select_field['preferences'] = { 'allow_multiple_values' => true }
        select_field['options'] = [
          { 'uuid' => 'opt_acc', 'value' => 'Accounts' },
          { 'uuid' => 'opt_hr', 'value' => 'HR' }
        ]
        text_field['conditions'] = [{
          'field_uuid' => select_field['uuid'],
          'action' => 'contains',
          'value' => 'opt_hr'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => %w[Accounts HR],
            text_field['uuid'] => 'Some value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Some value')
      end

      it '6. FEATURE #7 MULTI SELECT - CUSTOM LITERAL: evaluates multi select contains with custom literal value' do
        select_field['preferences'] = { 'allow_multiple_values' => true, 'allow_custom_value' => true }
        select_field['options'] = [
          { 'uuid' => 'opt_acc', 'value' => 'Accounts' }
        ]
        text_field['conditions'] = [{
          'field_uuid' => select_field['uuid'],
          'action' => 'contains',
          'value' => 'external consultant'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => ['Accounts', 'External Consultant'],
            text_field['uuid'] => 'Some value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Some value')
      end

      it '7. HIDDEN REQUIRED FIELD DOES NOT BLOCK: does not raise RequiredFieldError when required field is hidden' do
        submission.template_fields.each { |f| f['required'] = false }
        text_field['required'] = true

        select_field['options'] = [{ 'uuid' => 'opt_hr', 'value' => 'HR' }]
        text_field['conditions'] = [{
          'field_uuid' => select_field['uuid'],
          'action' => 'equal',
          'value' => 'opt_hr' # false condition since select_field value will be 'Accounts'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        target_snapshot = submission.template_fields.find { |f| f['uuid'] == text_field['uuid'] }
        source_snapshot = submission.template_fields.find { |f| f['uuid'] == select_field['uuid'] }

        expect(target_snapshot['required']).to be(true)
        expect(target_snapshot['conditions']).to be_present
        expect(source_snapshot['required']).to be(false)

        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'Accounts',
            text_field['uuid'] => '' # missing required value, but it is hidden
          },
          completed: 'true'
        )

        expect do
          described_class.call(submitter, params, request, validate_required: true)
        end.not_to raise_error

        expect(submitter.reload.values).not_to have_key(text_field['uuid'])
      end

      it '8. STALE HIDDEN VALUE REMOVAL: removes stale target value when condition becomes false' do
        select_field['options'] = [{ 'uuid' => 'opt1', 'value' => 'Option 1' }]
        submitter.update!(values: { text_field['uuid'] => 'Stale Value' })

        text_field['conditions'] = [{
          'field_uuid' => select_field['uuid'],
          'action' => 'equal',
          'value' => 'opt1'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'Wrong Option'
          },
          completed: 'true'
        )

        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to be_nil
      end

      it '9. AND CONDITIONS: evaluates multiple conditions correctly' do
        text_field['conditions'] = [
          { 'field_uuid' => select_field['uuid'], 'action' => 'equal', 'value' => 'hr' },
          { 'operation' => 'and', 'field_uuid' => number_field['uuid'], 'action' => 'equal', 'value' => '100' }
        ]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        # Both true
        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'HR',
            number_field['uuid'] => 100,
            text_field['uuid'] => 'Value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Value')

        # One false
        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'HR',
            number_field['uuid'] => 99,
            text_field['uuid'] => 'Value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to be_nil
      end

      it '10. OR CONDITIONS: evaluates multiple conditions correctly' do
        text_field['conditions'] = [
          { 'field_uuid' => select_field['uuid'], 'action' => 'equal', 'value' => 'hr' },
          { 'operation' => 'or', 'field_uuid' => number_field['uuid'], 'action' => 'equal', 'value' => '100' }
        ]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        # One true, one false
        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'Accounts', # false
            number_field['uuid'] => 100, # true
            text_field['uuid'] => 'Value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to eq('Value')

        # Both false
        params = ActionController::Parameters.new(
          values: {
            select_field['uuid'] => 'Accounts',
            number_field['uuid'] => 99,
            text_field['uuid'] => 'Value'
          },
          completed: 'true'
        )
        described_class.call(submitter, params, request, validate_required: false)
        expect(submitter.reload.values[text_field['uuid']]).to be_nil
      end

      it '11. MISSING / DELETED SOURCE FIELD: fails safely if source field is missing' do
        text_field['conditions'] = [{
          'field_uuid' => 'deleted_uuid',
          'action' => 'not_empty'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            text_field['uuid'] => 'Value'
          },
          completed: 'true'
        )
        expect do
          described_class.call(submitter, params, request, validate_required: false)
        end.not_to raise_error

        expect(submitter.reload.values[text_field['uuid']]).to be_nil
      end

      it '12. CYCLE SAFETY: safely evaluates cyclic conditions as false without stack overflow' do
        # A -> B, B -> A
        text_field['conditions'] = [{
          'field_uuid' => number_field['uuid'],
          'action' => 'equal',
          'value' => '1'
        }]
        number_field['conditions'] = [{
          'field_uuid' => text_field['uuid'],
          'action' => 'equal',
          'value' => '1'
        }]
        submission.template_fields_will_change!
        submission.save!
        submission.reload
        submitter.reload

        params = ActionController::Parameters.new(
          values: {
            text_field['uuid'] => '1',
            number_field['uuid'] => 1
          },
          completed: 'true'
        )

        expect do
          described_class.call(submitter, params, request, validate_required: false)
        end.not_to raise_error

        expect(submitter.reload.values[text_field['uuid']]).to be_nil
        expect(submitter.reload.values[number_field['uuid']]).to be_nil
      end
    end
  end
end
