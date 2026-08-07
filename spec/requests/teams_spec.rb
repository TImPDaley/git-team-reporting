# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams", type: :request do
  describe "CRUD" do
    it "lists teams" do
      create(:team, name: "Platform")
      get teams_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Platform")
    end

    it "creates a team" do
      expect {
        post teams_path, params: { team: { name: "Mobile", description: "Apps" } }
      }.to change(Team, :count).by(1)
      expect(response).to redirect_to(team_path(Team.last))
    end

    it "updates a team" do
      team = create(:team, name: "Old")
      patch team_path(team), params: { team: { name: "New" } }
      expect(response).to redirect_to(team_path(team))
      expect(team.reload.name).to eq("New")
    end

    it "destroys a team without repositories" do
      team = create(:team)
      expect {
        delete team_path(team)
      }.to change(Team, :count).by(-1)
      expect(response).to redirect_to(teams_path)
    end

    it "does not destroy a team that still has repositories" do
      team = create(:team)
      create(:repository, team: team)
      expect {
        delete team_path(team)
      }.not_to change(Team, :count)
      expect(response).to redirect_to(team_path(team))
    end
  end
end
