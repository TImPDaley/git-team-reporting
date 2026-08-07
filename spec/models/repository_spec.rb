# frozen_string_literal: true

require "rails_helper"

RSpec.describe Repository, type: :model do
  subject(:repository) { build(:repository) }

  it { is_expected.to belong_to(:team) }
  it { is_expected.to validate_presence_of(:owner) }
  it { is_expected.to validate_presence_of(:name) }

  it "builds a full_name" do
    repository = build(:repository, owner: "example-org", name: "my-app")
    expect(repository.full_name).to eq("example-org/my-app")
  end

  it "enforces unique owner/name pairs" do
    create(:repository, owner: "example-org", name: "my-app")
    duplicate = build(:repository, owner: "example-org", name: "my-app")
    expect(duplicate).not_to be_valid
  end
end
