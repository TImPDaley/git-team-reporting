# frozen_string_literal: true

module Reports
  # Orchestrates GitHub fetch + developer matching + metrics aggregation.
  class Generator
    Result = Data.define(
      :repository,
      :team,
      :date_range,
      :metrics,
      :generated_at,
      :token_source
    )

    def self.call(repository:, start_date:, end_date:, token:, token_source: :env, api_endpoint: nil)
      new(
        repository: repository,
        start_date: start_date,
        end_date: end_date,
        token: token,
        token_source: token_source,
        api_endpoint: api_endpoint
      ).call
    end

    def initialize(repository:, start_date:, end_date:, token:, token_source: :env, api_endpoint: nil)
      @repository = repository
      @start_date = start_date
      @end_date = end_date
      @token = token
      @token_source = token_source
      @api_endpoint = api_endpoint
    end

    def call
      raise Github::ConfigurationError, "A GitHub personal access token is required." if token.blank?

      client = Github::ClientFactory.build(token: token, api_endpoint: api_endpoint)
      activity = Github::ActivityFetcher.call(
        client: client,
        owner: repository.owner,
        repo: repository.name,
        start_date: start_date,
        end_date: end_date
      )

      team_members = repository.team.team_members.to_a
      metrics = MetricsAggregator.call(activity: activity, team_members: team_members)

      Result.new(
        repository: repository,
        team: repository.team,
        date_range: DateRange::Result.new(
          start_date: start_date.to_date,
          end_date: end_date.to_date,
          preset: "custom",
          label: "#{start_date.to_date} – #{end_date.to_date}"
        ),
        metrics: metrics,
        generated_at: Time.current,
        token_source: token_source
      )
    end

    private

    attr_reader :repository, :start_date, :end_date, :token, :token_source, :api_endpoint
  end
end
