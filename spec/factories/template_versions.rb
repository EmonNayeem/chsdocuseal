# frozen_string_literal: true

FactoryBot.define do
  factory :template_version do
    template
    account { template.account }
    company { template.company }
    author { template.author }
    data { TemplateVersions.build_data(template) }
    sha1 { Digest::SHA1.hexdigest(data.to_json) }
  end
end
