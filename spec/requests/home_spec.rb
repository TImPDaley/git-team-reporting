# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home", type: :request do
  it "renders the dashboard" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Git Team Reporting")
  end
end
