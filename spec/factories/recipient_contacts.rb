# frozen_string_literal: true

FactoryBot.define do
  factory :recipient_contact do
    account
    name { 'John Doe' }
    sequence(:email) { |n| "recipient#{n}@example.com" }
    phone { '+1234567890' }

    trait :shared do
      company_id { nil }
    end
  end
end
