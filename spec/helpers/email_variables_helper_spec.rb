require 'rails_helper'

RSpec.describe EmailVariablesHelper, type: :helper do
  describe '#invitation_email_variables' do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }
    let(:template) do
      t = create(:template, author: user, account: account, folder: account.default_template_folder)
      t.update!(submitters: submitters)
      t
    end
    let(:submitters) do
      [
        { 'name' => 'Employee' },
        { 'name' => 'Line Manager' },
        { 'name' => 'ICT Approver' },
        { 'name' => 'Finance Approver' },
        { 'name' => 'Department Head' },
        { 'name' => 'Director' }
      ]
    end

    it 'returns base variables if no template is passed' do
      result = helper.invitation_email_variables
      expect(result).to eq(AccountConfig::EMAIL_VARIABLES[AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY])
    end

    it 'returns grouped variables for each template party' do
      result = helper.invitation_email_variables(template)
      
      expect(result.first[:group]).to eq('General')
      expect(result.first[:items]).to eq(AccountConfig::EMAIL_VARIABLES[AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY])

      expect(result.length).to eq(7) # 1 general + 6 parties

      party1 = result[1]
      expect(party1[:group]).to eq('Employee')
      expect(party1[:items]).to include(
        { label: 'Name', value: 'submitters[1].name' },
        { label: 'First name', value: 'submitters[1].first_name' },
        { label: 'Email', value: 'submitters[1].email' }
      )

      party6 = result[6]
      expect(party6[:group]).to eq('Director')
      expect(party6[:items]).to include(
        { label: 'Name', value: 'submitters[6].name' },
        { label: 'First name', value: 'submitters[6].first_name' },
        { label: 'Email', value: 'submitters[6].email' }
      )
    end
  end
end
