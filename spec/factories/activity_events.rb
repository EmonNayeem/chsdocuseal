# frozen_string_literal: true

FactoryBot.define do
  factory :activity_event do
    account
    action { 'recipient_contact.created' }
    subject_type { 'RecipientContact' }
    subject_id { 1 }
    subject_label { 'John Doe <john@example.com>' }
    actor_name { 'Alice Admin' }
    actor_email { 'alice@example.com' }
    visibility_scope { 'account' }
    metadata { {} }
    occurred_at { Time.current }

    trait :company_scoped do
      visibility_scope { 'company' }
      company { account.companies.find_by(code: 'CHS') || account.companies.first }
    end

    trait :with_actor do
      actor_user { association :user, account: }
      actor_name { actor_user.full_name }
      actor_email { actor_user.email }
    end
  end
end
