# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Skip in test so request specs do not need a full modern User-Agent.
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :github_config, :github_token_status, :github_api_endpoint, :github_default_owner

  private

  def github_config
    @github_config ||= Github::ConfigResolver.call(session: session)
  end

  def github_token_status
    @github_token_status ||= Github::TokenResolver.call(session: session)
  end

  def github_api_endpoint
    github_config.api_endpoint
  end

  def github_default_owner
    github_config.default_owner
  end

  def require_github_token!
    return if github_token_status.present?

    redirect_to settings_path, alert: "Add a GitHub PAT via environment variable or session override before generating reports."
  end
end
