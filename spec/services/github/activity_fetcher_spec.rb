# frozen_string_literal: true

require "rails_helper"

RSpec.describe Github::ActivityFetcher do
  let(:api_endpoint) { "https://git.example.test/api/v3" }
  let(:client) do
    Octokit::Client.new(access_token: "test-token", api_endpoint: api_endpoint).tap do |c|
      c.auto_paginate = false
    end
  end
  let(:start_date) { Date.new(2026, 8, 1) }
  let(:end_date) { Date.new(2026, 8, 7) }
  let(:repo) { "example-org/demo" }

  def stub_json(method, path, body, status: 200)
    stub_request(method, "#{api_endpoint}#{path}")
      .to_return(
        status: status,
        body: body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  before do
    stub_json(:get, "/repos/#{repo}", { full_name: repo })
    stub_json(:get, "/repos/#{repo}/commits?since=2026-08-01T00%3A00%3A00Z&until=2026-08-07T23%3A59%3A59Z", [
      {
        sha: "abc123",
        author: { login: "alice" },
        committer: { login: "alice" },
        commit: {
          author: { name: "Alice", email: "alice@example.com", date: "2026-08-02T12:00:00Z" },
          committer: { name: "Alice", email: "alice@example.com", date: "2026-08-02T12:00:00Z" }
        }
      }
    ])
    stub_json(:get, "/repos/#{repo}/commits/abc123", {
      sha: "abc123",
      stats: { additions: 11, deletions: 4 }
    })
    stub_json(:get, "/repos/#{repo}/pulls?state=all", [
      {
        number: 1,
        title: "Add feature",
        state: "closed",
        user: { login: "alice" },
        created_at: "2026-08-02T10:00:00Z",
        closed_at: "2026-08-03T10:00:00Z",
        merged_at: "2026-08-03T10:00:00Z",
        merged: true,
        additions: 20,
        deletions: 2
      }
    ])
    stub_json(:get, "/repos/#{repo}/pulls/1/reviews", [
      {
        id: 55,
        user: { login: "bob" },
        state: "APPROVED",
        submitted_at: "2026-08-02T18:00:00Z"
      }
    ])
    stub_json(:get, "/repos/#{repo}/issues?state=all", [
      {
        number: 2,
        title: "Bug",
        state: "closed",
        user: { login: "alice" },
        created_at: "2026-08-02T09:00:00Z",
        closed_at: "2026-08-04T09:00:00Z"
      },
      {
        number: 1,
        title: "Add feature",
        state: "closed",
        user: { login: "alice" },
        created_at: "2026-08-02T10:00:00Z",
        closed_at: "2026-08-03T10:00:00Z",
        pull_request: { url: "#{api_endpoint}/repos/#{repo}/pulls/1" }
      }
    ])
  end

  it "fetches commits, PRs, reviews, and issues in range" do
    activity = described_class.call(
      client: client,
      owner: "example-org",
      repo: "demo",
      start_date: start_date,
      end_date: end_date
    )

    expect(activity.commits.size).to eq(1)
    expect(activity.commits.first.additions).to eq(11)
    expect(activity.pull_requests.size).to eq(1)
    expect(activity.reviews.size).to eq(1)
    expect(activity.issues.size).to eq(2)
    expect(activity.issues.count(&:pull_request)).to eq(1)
  end

  it "maps not found to Github::NotFoundError" do
    stub_request(:get, "#{api_endpoint}/repos/#{repo}")
      .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: { "Content-Type" => "application/json" })

    expect {
      described_class.call(client: client, owner: "example-org", repo: "demo", start_date: start_date, end_date: end_date)
    }.to raise_error(Github::NotFoundError)
  end

  it "maps rate limits to Github::RateLimitError" do
    stub_request(:get, "#{api_endpoint}/repos/#{repo}")
      .to_return(
        status: 403,
        body: { message: "API rate limit exceeded" }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "X-RateLimit-Remaining" => "0",
          "X-RateLimit-Reset" => 1.hour.from_now.to_i.to_s
        }
      )

    expect {
      described_class.call(client: client, owner: "example-org", repo: "demo", start_date: start_date, end_date: end_date)
    }.to raise_error(Github::RateLimitError)
  end
end
