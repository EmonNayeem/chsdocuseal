require 'rails_helper'

RSpec.describe ReplaceEmailVariables do
  let(:account) { create(:account, name: 'My Company') }
  let(:user) { create(:user, account: account, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }
  let(:template) { create(:template, account: account, author: user, name: 'My Template') }
  let(:submission) { create(:submission, account: account, template: template, created_by_user: user) }
  let(:submitter) { create(:submitter, submission: submission, name: 'John Doe', email: 'john@example.com', uuid: SecureRandom.uuid) }

  it 'replaces variables correctly' do
    text = 'Hi {submitter.first_name}, {template.name}, {submitter.name}'
    result = described_class.call(text, submitter: submitter)
    expect(result).to include('Hi John, My Template, John Doe')
  end

  it 'fixes auto-linked variables from markdown editor' do
    text = <<~TEXT
      Template: {[template.name](http://template.name)}
      Recipient: {[submitter.name](http://submitter.name)}
      Recipient Email: {[submitter.email](mailto:submitter.email)}
      Recipient Link: {[submitter.link](http://submitter.link)}
      Sender: {[sender.name](http://sender.name)}
      Sender Email: {[sender.email](mailto:sender.email)}
      Account: {[account.name](http://account.name)}
    TEXT

    result = described_class.call(text, submitter: submitter)

    expect(result).to include('Template: My Template')
    expect(result).to include('Recipient: John Doe')
    expect(result).to include('Recipient Email: john@example.com')
    expect(result).not_to include('{[submitter.link]')
    expect(result).to include('Sender: Jane Smith')
    expect(result).to include('Sender Email: jane@example.com')
    expect(result).to include('Account: My Company')
  end

  it 'does not alter legitimate markdown links or plain text inadvertently' do
    text = <<~TEXT
      Link: [{submitter.link}](https://example.com)
      URL: https://example.com
      Domain: normal.name
      Email: someone@example.com
    TEXT
    
    result = described_class.call(text, submitter: submitter)

    expect(result).to match(/Link: \[https?:\/\/[^\]]+\]\(https:\/\/example\.com\)/)
    expect(result).to include('URL: https://example.com')
    expect(result).to include('Domain: normal.name')
    expect(result).to include('Email: someone@example.com')
  end

  describe '.normalize_editor_variables' do
    it 'unwraps tiptap autolink formatting for variables' do
      expect(described_class.normalize_editor_variables('{[submitter.link](http://submitter.link)}')).to eq('{submitter.link}')
      expect(described_class.normalize_editor_variables('{[submitter.link](http://submitter.link/)}')).to eq('{submitter.link}')
      expect(described_class.normalize_editor_variables('{[submitter.name](http://submitter.name)}')).to eq('{submitter.name}')
      expect(described_class.normalize_editor_variables('{[submitter.name](http://submitter.name/)}')).to eq('{submitter.name}')
      expect(described_class.normalize_editor_variables('{[submitter.email](mailto:submitter.email)}')).to eq('{submitter.email}')
    end

    it 'leaves plain links and custom markdown links alone' do
      expect(described_class.normalize_editor_variables('[Review and Sign]({submitter.link})')).to eq('[Review and Sign]({submitter.link})')
      expect(described_class.normalize_editor_variables('[Website](https://example.com)')).to eq('[Website](https://example.com)')
      expect(described_class.normalize_editor_variables('http://normal.name/')).to eq('http://normal.name/')
    end
  end
end
