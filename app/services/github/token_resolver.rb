# frozen_string_literal: true

module Github
  # Backwards-compatible token-only facade over ConfigResolver.
  class TokenResolver
    Result = Data.define(:token, :source) do
      def present?
        token.present?
      end

      def from_session?
        source == :session
      end

      def from_env?
        source == :env
      end
    end

    def self.call(session: {})
      config = ConfigResolver.call(session: session)
      Result.new(token: config.token, source: config.token_source)
    end
  end
end
