# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamMember, type: :model do
  subject(:member) { build(:team_member) }

  it { is_expected.to belong_to(:team) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:email) }

  it "normalizes email and github username" do
    member = create(:team_member, email: "  Alex@Example.COM ", github_username: "@AlexDev")
    expect(member.email).to eq("alex@example.com")
    expect(member.github_username).to eq("AlexDev")
  end

  it "enforces unique email per team" do
    team = create(:team)
    create(:team_member, team: team, email: "same@example.com")
    duplicate = build(:team_member, team: team, email: "same@example.com")
    expect(duplicate).not_to be_valid
  end

  it "allows the same email on different teams" do
    create(:team_member, email: "shared@example.com")
    other = build(:team_member, email: "shared@example.com")
    expect(other).to be_valid
  end
end
