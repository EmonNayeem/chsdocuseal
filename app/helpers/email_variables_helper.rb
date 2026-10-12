# frozen_string_literal: true

module EmailVariablesHelper
  def template_email_variables(config_key, template = nil)
    base_variables = AccountConfig::EMAIL_VARIABLES[config_key]
    return base_variables unless template

    submitters = template.submitters || []

    party_groups = submitters.each_with_index.map do |party, index|
      party_name = party['name'].presence || "Party #{index + 1}"
      {
        group: party_name,
        items: [
          { label: 'Name', value: "submitters[#{index + 1}].name" },
          { label: 'First name', value: "submitters[#{index + 1}].first_name" },
          { label: 'Email', value: "submitters[#{index + 1}].email" },
          { label: 'Job title', value: "submitters[#{index + 1}].job_title" },
          { label: 'Department', value: "submitters[#{index + 1}].department" }
        ]
      }
    end

    if [AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY, AccountConfig::SUBMITTER_VIEW_INVITATION_EMAIL_KEY, AccountConfig::SUBMITTER_INVITATION_REMINDER_EMAIL_KEY].include?(config_key)
      base_variables += [
        { label: 'Recipient Name', value: 'recipient.name' },
        { label: 'Recipient Email', value: 'recipient.email' },
        { label: 'Recipient Phone', value: 'recipient.phone' },
        { label: 'Recipient Job title', value: 'recipient.job_title' },
        { label: 'Recipient Department', value: 'recipient.department' }
      ]
    end

    [
      { group: 'General', items: base_variables }
    ] + party_groups
  end

  def invitation_email_variables(template = nil)
    template_email_variables(AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY, template)
  end
end
