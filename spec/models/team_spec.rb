# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team, type: :model do
  subject(:team) { build(:team) }

  it { is_expected.to have_many(:team_members).dependent(:destroy) }
  it { is_expected.to have_many(:repositories).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:name) }

  it "requires a unique name" do
    create(:team, name: "Platform")
    duplicate = build(:team, name: "Platform")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "can be created with members" do
    team = create(:team)
    member = create(:team_member, team: team)
    expect(team.team_members).to contain_exactly(member)
  end
end
