# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::DeveloperMatcher do
  let(:team) { create(:team) }
  let!(:alice) { create(:team_member, team: team, name: "Alice", email: "alice@example.com", github_username: "alicegh") }
  let!(:bob) { create(:team_member, team: team, name: "Bob", email: "bob@example.com", github_username: nil) }

  subject(:matcher) { described_class.new(team.team_members) }

  it "matches by github username case-insensitively" do
    match = matcher.match(login: "AliceGH")
    expect(match.team_member).to eq(alice)
    expect(match.matched_by).to eq(:github_username)
  end

  it "matches by email when username is unknown" do
    match = matcher.match(login: "other", email: "bob@example.com")
    expect(match.team_member).to eq(bob)
    expect(match.matched_by).to eq(:email)
  end

  it "returns unmatched when no identity maps to a member" do
    match = matcher.match(login: "stranger", email: "stranger@example.com")
    expect(match.team_member).to be_nil
    expect(match.matched_by).to eq(:unmatched)
    expect(match.key).to eq("login:stranger")
  end
end
