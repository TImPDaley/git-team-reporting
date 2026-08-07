# frozen_string_literal: true

FactoryBot.define do
  factory :repository do
    team
    owner { "example-org" }
    sequence(:name) { |n| "example-repo-#{n}" }
  end
end
