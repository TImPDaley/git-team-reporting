# frozen_string_literal: true

require "rails_helper"

RSpec.describe Github::TokenResolver do
  around do |example|
    original = ENV.to_hash.slice("GITHUB_TOKEN", "GITHUB_ENTERPRISE_TOKEN")
    ENV.delete("GITHUB_TOKEN")
    ENV.delete("GITHUB_ENTERPRISE_TOKEN")
    example.run
  ensure
    ENV.delete("GITHUB_TOKEN")
    ENV.delete("GITHUB_ENTERPRISE_TOKEN")
    original.each { |k, v| ENV[k] = v }
  end

  it "returns missing when no token is configured" do
    result = described_class.call(session: {})
    expect(result).not_to be_present
    expect(result.source).to eq(:missing)
  end

  it "prefers session override over environment" do
    ENV["GITHUB_TOKEN"] = "env-token"
    session = { github_pat: "session-token" }
    result = described_class.call(session: session)
    expect(result.token).to eq("session-token")
    expect(result.source).to eq(:session)
  end

  it "uses GITHUB_TOKEN from the environment" do
    ENV["GITHUB_TOKEN"] = "env-token"
    result = described_class.call(session: {})
    expect(result.token).to eq("env-token")
    expect(result.source).to eq(:env)
  end

  it "falls back to GITHUB_ENTERPRISE_TOKEN" do
    ENV["GITHUB_ENTERPRISE_TOKEN"] = "ghe-token"
    result = described_class.call(session: {})
    expect(result.token).to eq("ghe-token")
    expect(result.source).to eq(:env)
  end
end
