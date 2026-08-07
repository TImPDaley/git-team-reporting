# frozen_string_literal: true

FactoryBot.define do
  factory :team_member do
    team
    sequence(:name) { |n| "Developer #{n}" }
    sequence(:email) { |n| "dev#{n}@example.com" }
    sequence(:github_username) { |n| "devuser#{n}" }
  end
end
