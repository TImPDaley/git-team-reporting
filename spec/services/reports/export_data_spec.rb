# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::ExportData do
  let(:payload) do
    {
      "repository_full_name" => "example-org/demo",
      "team_name" => "Platform",
      "date_label" => "This week (2026-08-01 – 2026-08-07)",
      "start_date" => "2026-08-01",
      "end_date" => "2026-08-07",
      "generated_at" => "2026-08-05T12:00:00Z",
      "unique_contributors" => 1,
      "repo_totals" => {
        "commits" => 3,
        "prs_opened" => 1,
        "prs_merged" => 1,
        "prs_closed_unmerged" => 0,
        "reviews" => 2,
        "lines_added" => 10,
        "lines_deleted" => 4,
        "issues_created" => 0,
        "issues_closed" => 0,
        "average_pr_cycle_time_hours" => 12.5
      },
      "team_totals" => {
        "commits" => 3,
        "prs_opened" => 1,
        "prs_merged" => 1,
        "prs_closed_unmerged" => 0,
        "reviews" => 2,
        "lines_added" => 10,
        "lines_deleted" => 4,
        "issues_created" => 0,
        "issues_closed" => 0,
        "average_pr_cycle_time_hours" => 12.5
      },
      "developers" => [
        {
          "display_name" => "Alice",
          "matched" => true,
          "matched_by" => "github_username",
          "commits" => 3,
          "prs_opened" => 1,
          "prs_merged" => 1,
          "prs_closed_unmerged" => 0,
          "reviews" => 2,
          "issues_created" => 0,
          "issues_closed" => 0,
          "lines_added" => 10,
          "lines_deleted" => 4,
          "average_pr_cycle_time_hours" => 12.5,
          "commits_as_author" => 3,
          "commits_as_committer" => 3
        }
      ],
      "unmatched" => []
    }
  end

  subject(:data) { described_class.wrap(payload) }

  it "exposes metadata and stable developer headers" do
    expect(data.repository_full_name).to eq("example-org/demo")
    expect(data.team_name).to eq("Platform")
    expect(data.developer_headers).to include("Developer", "Commits", "Avg PR cycle (h)")
  end

  it "formats nil cycle times as blank cells" do
    payload["developers"][0]["average_pr_cycle_time_hours"] = nil
    row = described_class.wrap(payload).developers.first
    values = described_class.wrap(payload).developer_values(row)
    cycle_index = described_class::DEVELOPER_COLUMNS.index { |c| c[:key] == :average_pr_cycle_time_hours }
    expect(values[cycle_index]).to eq("")
  end
end
