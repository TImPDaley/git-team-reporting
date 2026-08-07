# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::CsvRenderer do
  let(:payload) do
    {
      "repository_full_name" => "example-org/demo",
      "team_name" => "Platform",
      "date_label" => "Custom (2026-03-01 – 2026-03-15)",
      "start_date" => "2026-03-01",
      "end_date" => "2026-03-15",
      "generated_at" => "2026-08-05T12:00:00Z",
      "unique_contributors" => 1,
      "repo_totals" => { "commits" => 2, "prs_opened" => 0, "prs_merged" => 0, "prs_closed_unmerged" => 0,
                        "reviews" => 0, "lines_added" => 1, "lines_deleted" => 0, "issues_created" => 0,
                        "issues_closed" => 0, "average_pr_cycle_time_hours" => nil },
      "team_totals" => { "commits" => 2, "prs_opened" => 0, "prs_merged" => 0, "prs_closed_unmerged" => 0,
                        "reviews" => 0, "lines_added" => 1, "lines_deleted" => 0, "issues_created" => 0,
                        "issues_closed" => 0, "average_pr_cycle_time_hours" => nil },
      "developers" => [
        {
          "display_name" => "Alice",
          "matched" => true,
          "matched_by" => "github_username",
          "commits" => 2,
          "prs_opened" => 0,
          "prs_merged" => 0,
          "prs_closed_unmerged" => 0,
          "reviews" => 0,
          "issues_created" => 0,
          "issues_closed" => 0,
          "lines_added" => 1,
          "lines_deleted" => 0,
          "average_pr_cycle_time_hours" => nil,
          "commits_as_author" => 2,
          "commits_as_committer" => 2
        }
      ],
      "unmatched" => []
    }
  end

  it "renders UTF-8 CSV with metadata and developer rows" do
    csv = described_class.call(payload: payload)
    expect(csv).to include("example-org/demo")
    expect(csv).to include("Platform")
    expect(csv).to include("Developer")
    expect(csv).to include("Alice")
    expect(csv).not_to start_with("\uFEFF")
  end

  it "neutralizes spreadsheet formula injection in external text fields" do
    payload["developers"][0]["display_name"] = "=cmd|'/c calc'!A0"
    payload["team_name"] = "+dangerous"
    payload["repository_full_name"] = "@evil/repo"

    csv = described_class.call(payload: payload)
    expect(csv).to include("'=cmd|'/c calc'!A0")
    expect(csv).to include("'+dangerous")
    expect(csv).to include("'@evil/repo")
    # Numeric cells must not be quote-prefixed.
    expect(csv).to match(/,2(?:,|\r?\n)/)
  end
end
