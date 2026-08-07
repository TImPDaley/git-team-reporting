# frozen_string_literal: true

# GitHub API configuration (non-secret defaults).
# Token / session overrides are never written to the database or filesystem.
#
# ENV:
#   GITHUB_API_ENDPOINT     default: https://api.github.com
#   GITHUB_DEFAULT_OWNER    default: (blank)
#   GITHUB_TOKEN            preferred personal access token
#   GITHUB_ENTERPRISE_TOKEN alternate env key for the token
#
# Session keys (browser only, optional overrides via Settings UI):
#   github_pat, github_api_endpoint, github_default_owner
#
Rails.application.configure do
  config.x.github = ActiveSupport::OrderedOptions.new
  config.x.github.api_endpoint = ENV.fetch("GITHUB_API_ENDPOINT", "https://api.github.com")
  config.x.github.default_owner = ENV.fetch("GITHUB_DEFAULT_OWNER", "")
  config.x.github.token_env_keys = %w[GITHUB_TOKEN GITHUB_ENTERPRISE_TOKEN].freeze
  config.x.github.session_token_key = :github_pat
  config.x.github.session_api_endpoint_key = :github_api_endpoint
  config.x.github.session_default_owner_key = :github_default_owner
end
