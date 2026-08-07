# frozen_string_literal: true

module Github
  # Resolves runtime GitHub settings: session overrides first, then ENV/config defaults.
  # Session values are stored in the Rails session (encrypted cookie), never the database.
  class ConfigResolver
    Result = Data.define(
      :api_endpoint,
      :api_endpoint_source,
      :default_owner,
      :default_owner_source,
      :token,
      :token_source
    ) do
      def token_present?
        token.present?
      end

      def session_overrides?
        api_endpoint_source == :session ||
          default_owner_source == :session ||
          token_source == :session
      end
    end

    def self.call(session: {})
      new(session: session).call
    end

    def self.clear_session!(session)
      cfg = Rails.application.config.x.github
      [ cfg.session_token_key, cfg.session_api_endpoint_key, cfg.session_default_owner_key ].each do |key|
        session.delete(key)
        session.delete(key.to_s)
      end
    end

    def initialize(session: {})
      @session = session
      @cfg = Rails.application.config.x.github
    end

    def call
      endpoint = resolve_string(session_key: cfg.session_api_endpoint_key, fallback: cfg.api_endpoint)
      owner = resolve_string(session_key: cfg.session_default_owner_key, fallback: cfg.default_owner)
      token = resolve_token

      Result.new(
        api_endpoint: normalize_endpoint(endpoint[:value]),
        api_endpoint_source: endpoint[:source],
        default_owner: owner[:value],
        default_owner_source: owner[:source],
        token: token[:value],
        token_source: token[:source]
      )
    end

    private

    attr_reader :session, :cfg

    def resolve_string(session_key:, fallback:)
      session_value = session_read(session_key)
      if session_value
        { value: session_value, source: :session }
      else
        { value: fallback.to_s, source: :env }
      end
    end

    def resolve_token
      session_token = session_read(cfg.session_token_key)
      return { value: session_token, source: :session } if session_token

      cfg.token_env_keys.each do |key|
        value = ENV[key].to_s.strip.presence
        return { value: value, source: :env } if value
      end

      { value: nil, source: :missing }
    end

    # Cookie store may use string or symbol keys depending on access path.
    def session_read(key)
      value = session[key]
      value = session[key.to_s] if value.blank? && key.respond_to?(:to_s)
      value = session[key.to_sym] if value.blank? && key.respond_to?(:to_sym)
      value.to_s.strip.presence
    end

    def normalize_endpoint(value)
      raw = value.to_s.strip.chomp("/")
      return raw if raw.blank?

      # Common mistake: github.com web host instead of API host
      if raw.match?(%r{\Ahttps?://(www\.)?github\.com\z}i)
        return "https://api.github.com"
      end

      raw
    end
  end
end
