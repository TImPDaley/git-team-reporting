# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::MetricsAggregator do
  let(:team) { create(:team) }
  let!(:alice) { create(:team_member, team: team, name: "Alice", email: "alice@example.com", github_username: "alice") }
  let(:start_date) { Date.new(2026, 8, 1) }
  let(:end_date) { Date.new(2026, 8, 7) }

  let(:activity) do
    Github::ActivityFetcher::Activity.new(
      repo_full_name: "example-org/demo",
      start_date: start_date,
      end_date: end_date,
      commits: [
        Github::ActivityFetcher::CommitRecord.new(
          sha: "abc",
          author_login: "alice",
          author_email: "alice@example.com",
          author_name: "Alice",
          committer_login: "alice",
          committer_email: "alice@example.com",
          committer_name: "Alice",
          authored_at: Time.zone.parse("2026-08-02 10:00"),
          committed_at: Time.zone.parse("2026-08-02 10:00"),
          additions: 10,
          deletions: 2
        ),
        Github::ActivityFetcher::CommitRecord.new(
          sha: "def",
          author_login: "outsider",
          author_email: "out@example.com",
          author_name: "Outsider",
          committer_login: "outsider",
          committer_email: "out@example.com",
          committer_name: "Outsider",
          authored_at: Time.zone.parse("2026-08-03 10:00"),
          committed_at: Time.zone.parse("2026-08-03 10:00"),
          additions: 5,
          deletions: 1
        )
      ],
      pull_requests: [
        Github::ActivityFetcher::PullRequestRecord.new(
          number: 1,
          title: "Feature",
          state: "closed",
          user_login: "alice",
          user_email: nil,
          created_at: Time.zone.parse("2026-08-02 09:00"),
          closed_at: Time.zone.parse("2026-08-04 09:00"),
          merged_at: Time.zone.parse("2026-08-04 09:00"),
          merged: true,
          additions: 20,
          deletions: 3
        )
      ],
      reviews: [
        Github::ActivityFetcher::ReviewRecord.new(
          id: 9,
          pull_request_number: 1,
          user_login: "alice",
          user_email: nil,
          state: "APPROVED",
          submitted_at: Time.zone.parse("2026-08-03 12:00")
        )
      ],
      issues: [
        Github::ActivityFetcher::IssueRecord.new(
          number: 2,
          title: "Bug",
          state: "closed",
          user_login: "alice",
          user_email: nil,
          created_at: Time.zone.parse("2026-08-02 08:00"),
          closed_at: Time.zone.parse("2026-08-05 08:00"),
          pull_request: false
        )
      ]
    )
  end

  subject(:metrics) { described_class.call(activity: activity, team_members: team.team_members) }

  it "aggregates matched developer metrics" do
    alice_metrics = metrics.developers.find { |d| d.team_member == alice }
    expect(alice_metrics.commits).to eq(1)
    expect(alice_metrics.lines_added).to eq(10)
    expect(alice_metrics.lines_deleted).to eq(2)
    expect(alice_metrics.prs_opened).to eq(1)
    expect(alice_metrics.prs_merged).to eq(1)
    expect(alice_metrics.reviews).to eq(1)
    expect(alice_metrics.issues_created).to eq(1)
    expect(alice_metrics.issues_closed).to eq(1)
    expect(alice_metrics.average_pr_cycle_time_hours).to eq(48.0)
  end

  it "tracks unmatched contributors separately" do
    expect(metrics.unmatched_contributors.map(&:display_name).join).to include("Outsider")
    expect(metrics.unique_contributors).to eq(2)
  end

  it "computes team and repo totals" do
    expect(metrics.team_totals[:commits]).to eq(1)
    expect(metrics.repo_totals[:commits]).to eq(2)
  end
end
