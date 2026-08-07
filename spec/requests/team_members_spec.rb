# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team members", type: :request do
  let(:team) { create(:team) }

  it "adds a member to a team" do
    expect {
      post team_team_members_path(team), params: {
        team_member: { name: "Ada", email: "ada@example.com", github_username: "ada" }
      }
    }.to change(TeamMember, :count).by(1)
    expect(response).to redirect_to(team_path(team))
  end

  it "updates a member" do
    member = create(:team_member, team: team, name: "Old")
    patch team_team_member_path(team, member), params: {
      team_member: { name: "New Name", email: member.email, github_username: member.github_username }
    }
    expect(member.reload.name).to eq("New Name")
  end

  it "removes a member" do
    member = create(:team_member, team: team)
    expect {
      delete team_team_member_path(team, member)
    }.to change(TeamMember, :count).by(-1)
  end
end
