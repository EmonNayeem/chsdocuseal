module EmailVariablesHelper
  def invitation_email_variables(template = nil)
    base_variables = AccountConfig::EMAIL_VARIABLES[AccountConfig::SUBMITTER_INVITATION_EMAIL_KEY]
    return base_variables unless template

    submitters = template.submitters || []
    
    party_groups = submitters.each_with_index.map do |party, index|
      party_name = party['name'].presence || "Party #{index + 1}"
      {
        group: party_name,
        items: [
          { label: "Name", value: "submitters[#{index + 1}].name" },
          { label: "First name", value: "submitters[#{index + 1}].first_name" },
          { label: "Email", value: "submitters[#{index + 1}].email" }
        ]
      }
    end

    [
      { group: "General", items: base_variables }
    ] + party_groups
  end
end
