# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @config = github_config
    @env_api_endpoint = Rails.application.config.x.github.api_endpoint
    @env_default_owner = Rails.application.config.x.github.default_owner
  end

  def update
    settings = settings_params
    cfg = Rails.application.config.x.github
    changed = []

    if settings.key?(:api_endpoint)
      endpoint = normalize_api_endpoint(settings[:api_endpoint])
      if endpoint.blank?
        redirect_to settings_path, alert: "API endpoint cannot be blank."
        return
      end
      unless valid_api_endpoint?(endpoint)
        redirect_to settings_path, alert: api_endpoint_error_message(endpoint)
        return
      end

      env_default = normalize_api_endpoint(cfg.api_endpoint)
      if endpoint == env_default
        changed << "API endpoint cleared to environment default" if clear_session_key(cfg.session_api_endpoint_key)
      else
        session[cfg.session_api_endpoint_key] = endpoint
        changed << "API endpoint"
      end
    end

    if settings.key?(:default_owner)
      owner = settings[:default_owner].to_s.strip
      # Blank (or matching the env default) clears any session override so forms
      # use the environment value — which may itself be blank.
      if owner.blank? || owner == cfg.default_owner.to_s
        changed << "default owner cleared to environment default" if clear_session_key(cfg.session_default_owner_key)
      else
        session[cfg.session_default_owner_key] = owner
        changed << "default owner / org"
      end
    end

    if settings.key?(:github_pat)
      token = settings[:github_pat].to_s.strip
      if token.present?
        session[cfg.session_token_key] = token
        changed << "token"
      end
      # Blank token field means leave token unchanged.
    end

    if changed.empty?
      redirect_to settings_path, alert: "No session overrides were changed."
    else
      redirect_to settings_path, notice: "Session overrides updated (encrypted session cookie only): #{changed.join(', ')}."
    end
  end

  def destroy
    Github::ConfigResolver.clear_session!(session)
    redirect_to settings_path, notice: "All session overrides cleared (API endpoint, default owner, and token)."
  end

  private

  def settings_params
    params.fetch(:settings, {}).permit(:api_endpoint, :default_owner, :github_pat)
  end

  def normalize_api_endpoint(value)
    value.to_s.strip.chomp("/")
  end

  def valid_api_endpoint?(value)
    uri = URI.parse(value)
    return false unless uri.is_a?(URI::HTTP) && uri.host.present?

    # Reject common mistakes: repo web pages or github.com (non-API) hosts.
    path = uri.path.to_s.chomp("/")
    host = uri.host.to_s.downcase

    if host == "github.com" || host == "www.github.com"
      return false
    end

    # Path should be empty (api.github.com) or end with /api/v3 (GHE Server).
    return true if path.blank?
    return true if path == "/api/v3" || path.end_with?("/api/v3")

    false
  rescue URI::InvalidURIError
    false
  end


  def api_endpoint_error_message(value)
    host = begin
      URI.parse(value).host.to_s.downcase
    rescue URI::InvalidURIError
      ""
    end

    if host == "github.com" || host == "www.github.com" || value.to_s.include?("github.com/")
      "That looks like a GitHub website URL, not the API. For github.com use https://api.github.com " \
        "(owner/repo go on the Generate Report form, not in the endpoint)."
    else
      "API endpoint must be an API base URL, e.g. https://api.github.com or " \
        "https://git.example.com/api/v3 — not a repository web page."
    end
  end

  def clear_session_key(key)
    deleted = session.delete(key)
    deleted_s = session.delete(key.to_s)
    deleted.present? || deleted_s.present?
  end
end
