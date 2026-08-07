# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Repositories", type: :request do
  let(:team) { create(:team) }

  it "creates a repository linked to a team" do
    expect {
      post repositories_path, params: {
        repository: { owner: "example-org", name: "my-service", team_id: team.id }
      }
    }.to change(Repository, :count).by(1)
    expect(response).to redirect_to(repository_path(Repository.last))
    expect(Repository.last.team).to eq(team)
  end

  it "lists repositories" do
    create(:repository, team: team, owner: "example-org", name: "listed")
    get repositories_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("example-org/listed")
  end
end
