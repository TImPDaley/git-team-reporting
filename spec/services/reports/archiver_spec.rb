# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::Archiver do
  let(:team) { create(:team, name: "Platform") }
  let(:repository) { create(:repository, team: team, owner: "example-org", name: "demo") }
  let(:date_range) do
    Reports::DateRange::Result.new(
      start_date: Date.new(2026, 8, 1),
      end_date: Date.new(2026, 8, 7),
      preset: "this_week",
      label: "This week (2026-08-01 – 2026-08-07)"
    )
  end
  let(:metrics) do
    Reports::MetricsAggregator::ReportMetrics.new(
      developers: [],
      team_totals: {
        commits: 0, prs_opened: 0, prs_merged: 0, prs_closed_unmerged: 0,
        reviews: 0, lines_added: 0, lines_deleted: 0, issues_created: 0,
        issues_closed: 0, average_pr_cycle_time_hours: nil
      },
      repo_totals: {
        commits: 0, prs_opened: 0, prs_merged: 0, prs_closed_unmerged: 0,
        reviews: 0, lines_added: 0, lines_deleted: 0, issues_created: 0,
        issues_closed: 0, average_pr_cycle_time_hours: nil
      },
      unique_contributors: 0,
      unmatched_contributors: []
    )
  end
  let(:result) do
    Reports::Generator::Result.new(
      repository: repository,
      team: team,
      date_range: date_range,
      metrics: metrics,
      generated_at: Time.zone.parse("2026-08-05 12:00:00"),
      token_source: :env
    )
  end

  it "persists report metadata and HTML content" do
    report = nil
    expect {
      report = described_class.call(result: result, date_range: date_range, format: "html", preset: "this_week")
    }.to change(Report, :count).by(1)

    expect(report.repository_full_name).to eq("example-org/demo")
    expect(report.team_name).to eq("Platform")
    expect(report.start_date).to eq(Date.new(2026, 8, 1))
    expect(report.end_date).to eq(Date.new(2026, 8, 7))
    expect(report.format).to eq("html")
    expect(report.filename).to end_with(".html")
    expect(report.content).to include("example-org/demo")
    expect(report.content).to include("Platform")
    expect(report.metrics_payload["repository_full_name"]).to eq("example-org/demo")
  end

  %w[csv markdown pdf].each do |fmt|
    it "persists a #{fmt} report with the correct extension" do
      report = described_class.call(result: result, date_range: date_range, format: fmt, preset: "this_week")
      extension = Report::FORMATS.fetch(fmt).fetch(:extension)

      expect(report.format).to eq(fmt)
      expect(report.filename).to end_with(".#{extension}")
      expect(report.content).to be_present
      expect(report.metrics_payload["repository_full_name"]).to eq("example-org/demo")

      case fmt
      when "csv", "markdown"
        expect(report.content_for_display).to include("example-org/demo")
      when "pdf"
        expect(report.content).to start_with("%PDF")
      end
    end
  end

  it "rejects unknown formats" do
    expect {
      described_class.call(result: result, date_range: date_range, format: "xlsx")
    }.to raise_error(ArgumentError, /Unknown report format/)
  end
end
