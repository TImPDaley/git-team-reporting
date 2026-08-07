# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  let(:team) { create(:team) }
  let!(:member) { create(:team_member, team: team, github_username: "alice", email: "alice@example.com") }
  let!(:repository) { create(:repository, team: team, owner: "example-org", name: "demo") }
  let(:api_endpoint) { Rails.application.config.x.github.api_endpoint }

  around do |example|
    original = ENV["GITHUB_TOKEN"]
    ENV["GITHUB_TOKEN"] = "test-token"
    example.run
  ensure
    if original
      ENV["GITHUB_TOKEN"] = original
    else
      ENV.delete("GITHUB_TOKEN")
    end
  end

  def stub_github_activity
    repo = "example-org/demo"
    stub_request(:get, %r{#{Regexp.escape(api_endpoint)}/repos/#{repo}$})
      .to_return(status: 200, body: { full_name: repo }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{#{Regexp.escape(api_endpoint)}/repos/#{repo}/commits})
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{#{Regexp.escape(api_endpoint)}/repos/#{repo}/pulls})
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{#{Regexp.escape(api_endpoint)}/repos/#{repo}/issues})
      .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })
  end

  it "lists saved reports" do
    create(:report, repository: repository, team: team, repository_full_name: "example-org/demo", team_name: team.name)
    get reports_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("example-org/demo")
    expect(response.body).to include(team.name)
  end

  it "renders the generate form" do
    get new_report_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Generate report")
  end

  it "generates and persists an HTML report" do
    stub_github_activity

    expect {
      post reports_path, params: {
        report: {
          repository_id: repository.id,
          preset: "this_week",
          format: "html"
        }
      }
    }.to change(Report, :count).by(1)

    report = Report.order(:id).last
    expect(response).to redirect_to(report_path(report))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("example-org/demo")
    expect(response.body).to include(team.name)
    expect(report.content).to include("example-org/demo")
  end

  it "generates a report for an explicit custom date range" do
    stub_github_activity

    expect {
      post reports_path, params: {
        report: {
          repository_id: repository.id,
          preset: "custom",
          start_date: "2026-03-01",
          end_date: "2026-03-15",
          format: "html"
        }
      }
    }.to change(Report, :count).by(1)

    report = Report.order(:id).last
    expect(response).to redirect_to(report_path(report))
    expect(report.start_date).to eq(Date.new(2026, 3, 1))
    expect(report.end_date).to eq(Date.new(2026, 3, 15))
    expect(report.preset).to eq("custom")
  end

  it "honors filled custom dates even when a named preset is still selected" do
    stub_github_activity

    post reports_path, params: {
      report: {
        repository_id: repository.id,
        preset: "this_week",
        start_date: "2026-01-01",
        end_date: "2026-01-31",
        format: "html"
      }
    }

    report = Report.order(:id).last
    expect(response).to redirect_to(report_path(report))
    expect(report.start_date).to eq(Date.new(2026, 1, 1))
    expect(report.end_date).to eq(Date.new(2026, 1, 31))
    expect(report.preset).to eq("custom")
  end

  it "rejects custom preset without both dates" do
    expect {
      post reports_path, params: {
        report: {
          repository_id: repository.id,
          preset: "custom",
          start_date: "2026-03-01",
          end_date: "",
          format: "html"
        }
      }
    }.not_to change(Report, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("start_date and end_date")
  end

  it "downloads the stored report file" do
    report = create(:report, repository: repository, team: team, content: "<html>saved</html>", filename: "demo.html")
    get download_report_path(report)
    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Disposition"]).to include("demo.html")
    expect(response.body).to include("saved")
  end

  {
    "csv" => { extension: "csv", mime: "text/csv", body_match: "example-org/demo" },
    "markdown" => { extension: "md", mime: "text/markdown", body_match: "example-org/demo" },
    "pdf" => { extension: "pdf", mime: "application/pdf", body_match: "%PDF" }
  }.each do |format, meta|
    it "generates and downloads a #{format} report" do
      stub_github_activity

      expect {
        post reports_path, params: {
          report: {
            repository_id: repository.id,
            preset: "this_week",
            format: format
          }
        }
      }.to change(Report, :count).by(1)

      report = Report.order(:id).last
      expect(response).to redirect_to(report_path(report))
      expect(report.format).to eq(format)
      expect(report.filename).to end_with(".#{meta[:extension]}")

      get report_path(report)
      expect(response).to have_http_status(:ok)

      get download_report_path(report)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(meta[:mime])
      expect(response.headers["Content-Disposition"]).to include(meta[:extension])
      expect(response.body).to include(meta[:body_match])
    end
  end

  it "deletes a saved report" do
    report = create(:report, repository: repository, team: team)
    expect {
      delete report_path(report)
    }.to change(Report, :count).by(-1)
    expect(response).to redirect_to(reports_path)
  end

  it "redirects to settings when no token is configured" do
    ENV.delete("GITHUB_TOKEN")
    post reports_path, params: {
      report: { repository_id: repository.id, preset: "this_week", format: "html" }
    }
    expect(response).to redirect_to(settings_path)
  end
end
