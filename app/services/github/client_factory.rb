# frozen_string_literal: true

module Github
  class ClientFactory
    def self.build(token:, api_endpoint: nil)
      new(token: token, api_endpoint: api_endpoint).build
    end

    def initialize(token:, api_endpoint: nil)
      @token = token
      @api_endpoint = api_endpoint.presence || Rails.application.config.x.github.api_endpoint
    end

    def build
      raise ArgumentError, "GitHub token is required" if token.blank?

      Octokit::Client.new(
        access_token: token,
        api_endpoint: api_endpoint
      ).tap do |client|
        client.auto_paginate = true
      end
    end

    private

    attr_reader :token, :api_endpoint
  end
end
