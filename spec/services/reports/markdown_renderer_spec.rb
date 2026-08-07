# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::MarkdownRenderer do
  let(:payload) do
    {
      "repository_full_name" => "example-org/demo",
      "team_name" => "Platform",
      "date_label" => "This week (2026-08-01 – 2026-08-07)",
      "start_date" => "2026-08-01",
      "end_date" => "2026-08-07",
      "generated_at" => "2026-08-05T12:00:00Z",
      "unique_contributors" => 1,
      "repo_totals" => { "commits" => 1, "prs_opened" => 0, "prs_merged" => 0, "prs_closed_unmerged" => 0,
                        "reviews" => 0, "lines_added" => 0, "lines_deleted" => 0, "issues_created" => 0,
                        "issues_closed" => 0, "average_pr_cycle_time_hours" => nil },
      "team_totals" => { "commits" => 1, "prs_opened" => 0, "prs_merged" => 0, "prs_closed_unmerged" => 0,
                        "reviews" => 0, "lines_added" => 0, "lines_deleted" => 0, "issues_created" => 0,
                        "issues_closed" => 0, "average_pr_cycle_time_hours" => nil },
      "developers" => [
        {
          "display_name" => "Alice",
          "matched" => true,
          "matched_by" => "github_username",
          "commits" => 1,
          "prs_opened" => 0,
          "prs_merged" => 0,
          "prs_closed_unmerged" => 0,
          "reviews" => 0,
          "issues_created" => 0,
          "issues_closed" => 0,
          "lines_added" => 0,
          "lines_deleted" => 0,
          "average_pr_cycle_time_hours" => nil,
          "commits_as_author" => 1,
          "commits_as_committer" => 1
        }
      ],
      "unmatched" => []
    }
  end

  it "renders a GFM document with tables and metadata" do
    md = described_class.call(payload: payload)
    expect(md).to include("# Activity report: example-org/demo")
    expect(md).to include("**Team:** Platform")
    expect(md).to include("## By developer")
    expect(md).to include("| Developer |")
    expect(md).to include("Alice")
  end
end
