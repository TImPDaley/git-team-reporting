# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  it "shows settings with active connection values" do
    get settings_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Session connection overrides")
    expect(response.body).to include("API endpoint")
    expect(response.body).to include("Default owner / org")
  end

  it "stores a session token override" do
    patch settings_path, params: { settings: { github_pat: "session-secret-token" } }
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    expect(response.body).to include("session")
    expect(response.body).to include("Present")
  end

  it "stores session API endpoint and default owner overrides" do
    patch settings_path, params: {
      settings: {
        api_endpoint: "https://api.github.com",
        default_owner: "my-test-org"
      }
    }
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    expect(response.body).to include("https://api.github.com")
    expect(response.body).to include("my-test-org")
    # source badges should reflect session
    expect(response.body).to include("badge-emerald")
  end

  it "normalizes trailing slashes on API endpoint and clears when matching ENV default" do
    env_default = Rails.application.config.x.github.api_endpoint.to_s.chomp("/")
    patch settings_path, params: {
      settings: {
        api_endpoint: "#{env_default}/",
        default_owner: Rails.application.config.x.github.default_owner
      }
    }
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    # Treated as env default, not a sticky session override with trailing slash
    expect(response.body).to include(env_default)
    expect(response.body).not_to match(/API endpoint[\s\S]*badge-emerald/)
  end

  it "rejects an invalid API endpoint" do
    patch settings_path, params: {
      settings: {
        api_endpoint: "not-a-url",
        default_owner: "example-org"
      }
    }
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    expect(response.body).to include("API base URL")
  end

  it "rejects a repository web URL used as the API endpoint" do
    patch settings_path, params: {
      settings: {
        api_endpoint: "https://github.com/HelpUsFollowChrist/helpusfollowchrist",
        default_owner: "HelpUsFollowChrist"
      }
    }
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    expect(response.body).to include("https://api.github.com")
  end


  it "clears all session overrides" do
    patch settings_path, params: {
      settings: {
        api_endpoint: "https://api.github.com",
        default_owner: "acme",
        github_pat: "session-secret-token"
      }
    }
    delete settings_path
    expect(response).to redirect_to(settings_path)
    follow_redirect!
    expect(response.body).to include("Missing").or include("missing")
  end

  it "uses session default owner on the new repository form" do
    patch settings_path, params: {
      settings: {
        api_endpoint: Rails.application.config.x.github.api_endpoint,
        default_owner: "session-org"
      }
    }
    get new_repository_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('value="session-org"')
  end

  it "allows blank default owner and clears a prior session override" do
    patch settings_path, params: {
      settings: {
        api_endpoint: Rails.application.config.x.github.api_endpoint,
        default_owner: "temporary-org"
      }
    }
    patch settings_path, params: {
      settings: {
        api_endpoint: Rails.application.config.x.github.api_endpoint,
        default_owner: ""
      }
    }
    expect(response).to redirect_to(settings_path)

    get new_repository_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('value="temporary-org"')
  end
end
