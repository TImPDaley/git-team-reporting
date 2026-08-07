# frozen_string_literal: true

require "rails_helper"

RSpec.describe Github::ConfigResolver do
  around do |example|
    original = ENV.to_hash.slice("GITHUB_TOKEN", "GITHUB_ENTERPRISE_TOKEN", "GITHUB_API_ENDPOINT", "GITHUB_DEFAULT_OWNER")
    ENV.delete("GITHUB_TOKEN")
    ENV.delete("GITHUB_ENTERPRISE_TOKEN")
    example.run
  ensure
    ENV.delete("GITHUB_TOKEN")
    ENV.delete("GITHUB_ENTERPRISE_TOKEN")
    original.each { |k, v| ENV[k] = v }
  end

  it "uses environment defaults when session is empty" do
    result = described_class.call(session: {})
    expect(result.api_endpoint).to eq(Rails.application.config.x.github.api_endpoint)
    expect(result.api_endpoint).to eq("https://api.github.com")
    expect(result.api_endpoint_source).to eq(:env)
    expect(result.default_owner).to eq(Rails.application.config.x.github.default_owner)
    expect(result.default_owner).to eq("")
    expect(result.default_owner_source).to eq(:env)
    expect(result.token_source).to eq(:missing)
  end

  it "prefers session overrides for endpoint and owner" do
    session = {
      github_api_endpoint: "https://api.github.com/",
      github_default_owner: "acme-org",
      github_pat: "session-token"
    }
    result = described_class.call(session: session)
    expect(result.api_endpoint).to eq("https://api.github.com")
    expect(result.api_endpoint_source).to eq(:session)
    expect(result.default_owner).to eq("acme-org")
    expect(result.default_owner_source).to eq(:session)
    expect(result.token).to eq("session-token")
    expect(result.token_source).to eq(:session)
    expect(result.session_overrides?).to be(true)
  end

  it "clears all session keys" do
    session = {
      github_api_endpoint: "https://api.github.com",
      github_default_owner: "acme",
      github_pat: "tok"
    }
    described_class.clear_session!(session)
    expect(session).to be_empty
  end
end
