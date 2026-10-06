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
  end
end
