# frozen_string_literal: true

FactoryBot.define do
  factory :report do
    repository
    team { repository.team }
    repository_full_name { repository.full_name }
    team_name { team.name }
    start_date { Date.new(2026, 8, 1) }
    end_date { Date.new(2026, 8, 7) }
    date_range_label { "This week (2026-08-01 – 2026-08-07)" }
    preset { "this_week" }
    format { "html" }
    sequence(:filename) { |n| "example-org-demo-20260805-#{n}.html" }
    content { "<!DOCTYPE html><html><body><h1>Report</h1></body></html>" }
    metrics_payload do
      {
        "repository_full_name" => repository_full_name,
        "team_name" => team_name,
        "developers" => [],
        "unmatched" => [],
        "repo_totals" => { "commits" => 0 },
        "team_totals" => { "commits" => 0 },
        "unique_contributors" => 0
      }
    end
    generated_at { Time.current }
  end
end
