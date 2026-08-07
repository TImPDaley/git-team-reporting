# frozen_string_literal: true

module Github
  # Fetches repository activity for a date range via the GitHub Enterprise REST API.
  class ActivityFetcher
    CONNECTION_ERRORS = [
      (Faraday::ConnectionFailed if defined?(Faraday::ConnectionFailed)),
      (Faraday::TimeoutError if defined?(Faraday::TimeoutError)),
      (Faraday::Error if defined?(Faraday::Error)),
      (Socket::ResolutionError if defined?(Socket::ResolutionError)),
      SocketError,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH
    ].compact.freeze

    Activity = Data.define(
      :repo_full_name,
      :start_date,
      :end_date,
      :commits,
      :pull_requests,
      :reviews,
      :issues
    )

    CommitRecord = Data.define(
      :sha,
      :author_login,
      :author_email,
      :author_name,
      :committer_login,
      :committer_email,
      :committer_name,
      :authored_at,
      :committed_at,
      :additions,
      :deletions
    )

    PullRequestRecord = Data.define(
      :number,
      :title,
      :state,
      :user_login,
      :user_email,
      :created_at,
      :closed_at,
      :merged_at,
      :merged,
      :additions,
      :deletions
    )

    ReviewRecord = Data.define(
      :id,
      :pull_request_number,
      :user_login,
      :user_email,
      :state,
      :submitted_at
    )

    IssueRecord = Data.define(
      :number,
      :title,
      :state,
      :user_login,
      :user_email,
      :created_at,
      :closed_at,
      :pull_request
    )

    def self.call(client:, owner:, repo:, start_date:, end_date:)
      new(client: client, owner: owner, repo: repo, start_date: start_date, end_date: end_date).call
    end

    def initialize(client:, owner:, repo:, start_date:, end_date:)
      @client = client
      @owner = owner
      @repo = repo
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @repo_full_name = "#{owner}/#{repo}"
    end

    def call
      verify_repo!

      Activity.new(
        repo_full_name: repo_full_name,
        start_date: start_date,
        end_date: end_date,
        commits: fetch_commits,
        pull_requests: pull_requests,
        reviews: fetch_reviews(pull_requests),
        issues: fetch_issues
      )
    rescue Octokit::NotFound
      raise NotFoundError, "Repository #{repo_full_name} was not found or is not accessible."
    rescue Octokit::TooManyRequests => e
      raise RateLimitError, rate_limit_message(e)
    rescue Octokit::Unauthorized => e
      raise UnauthorizedError, "GitHub authentication failed: #{e.message}"
    rescue Octokit::Forbidden => e
      if rate_limited?(e)
        raise RateLimitError, rate_limit_message(e)
      end

      raise UnauthorizedError, "GitHub authentication failed: #{e.message}"
    rescue *CONNECTION_ERRORS => e
      raise ApiError, connection_error_message(e)
    rescue Octokit::Error => e
      raise ApiError, "GitHub API error: #{e.message}"
    end

    private

    attr_reader :client, :owner, :repo, :start_date, :end_date, :repo_full_name

    def pull_requests
      @pull_requests ||= fetch_pull_requests
    end

    def verify_repo!
      client.repository(repo_full_name)
    end

    def connection_error_message(error)
      endpoint = begin
        client.api_endpoint.to_s
      rescue StandardError
        "(unknown endpoint)"
      end

      "Could not reach GitHub API at #{endpoint}. " \
        "Open Settings and set API endpoint to https://api.github.com for github.com repos " \
        "(or https://your-ghe-host/api/v3 for Enterprise Server). " \
        "Details: #{error.class}: #{error.message}"
    end

    def rate_limited?(error)
      remaining = error.response_headers&.[]("X-RateLimit-Remaining") ||
                  error.response_headers&.[]("x-ratelimit-remaining")
      return true if remaining.to_s == "0"

      error.message.to_s.match?(/rate limit/i)
    end

    def rate_limit_message(error)
      reset = error.response_headers&.[]("X-RateLimit-Reset") ||
              error.response_headers&.[]("x-ratelimit-reset")
      message = "GitHub API rate limit exceeded."
      message += " Resets at #{Time.zone.at(reset.to_i)}." if reset.present?
      message
    end

    def range_start
      start_date.beginning_of_day
    end

    def range_end
      end_date.end_of_day
    end

    def in_range?(timestamp)
      return false if timestamp.blank?

      time = timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp.in_time_zone
      time >= range_start && time <= range_end
    end

    def fetch_commits
      commits = client.commits(
        repo_full_name,
        since: range_start.iso8601,
        until: range_end.iso8601
      )

      commits.filter_map do |commit|
        authored_at = commit.commit&.author&.date
        next unless in_range?(authored_at)

        stats = commit_stats(commit.sha)

        CommitRecord.new(
          sha: commit.sha,
          author_login: commit.author&.login,
          author_email: commit.commit&.author&.email,
          author_name: commit.commit&.author&.name,
          committer_login: commit.committer&.login,
          committer_email: commit.commit&.committer&.email,
          committer_name: commit.commit&.committer&.name,
          authored_at: authored_at,
          committed_at: commit.commit&.committer&.date,
          additions: stats[:additions],
          deletions: stats[:deletions]
        )
      end
    end

    def commit_stats(sha)
      detail = client.commit(repo_full_name, sha)
      {
        additions: detail.stats&.additions.to_i,
        deletions: detail.stats&.deletions.to_i
      }
    rescue Octokit::Error
      { additions: 0, deletions: 0 }
    end

    def fetch_pull_requests
      # state: all returns open + closed; filter by activity in range
      client.pull_requests(repo_full_name, state: "all").filter_map do |pr|
        created_in_range = in_range?(pr.created_at)
        closed_in_range = in_range?(pr.closed_at)
        merged_in_range = in_range?(pr.merged_at)
        next unless created_in_range || closed_in_range || merged_in_range

        PullRequestRecord.new(
          number: pr.number,
          title: pr.title,
          state: pr.state,
          user_login: pr.user&.login,
          user_email: nil,
          created_at: pr.created_at,
          closed_at: pr.closed_at,
          merged_at: pr.merged_at,
          merged: pr.merged_at.present? || pr.merged == true,
          additions: pr.additions.to_i,
          deletions: pr.deletions.to_i
        )
      end
    end

    def fetch_reviews(prs)
      prs.flat_map do |pr|
        client.pull_request_reviews(repo_full_name, pr.number).filter_map do |review|
          next unless in_range?(review.submitted_at)
          next if review.state.to_s.casecmp("pending").zero?

          ReviewRecord.new(
            id: review.id,
            pull_request_number: pr.number,
            user_login: review.user&.login,
            user_email: nil,
            state: review.state,
            submitted_at: review.submitted_at
          )
        end
      rescue Octokit::NotFound
        []
      end
    end

    def fetch_issues
      client.list_issues(repo_full_name, state: "all").filter_map do |issue|
        # GitHub issues API includes pull requests; mark them so callers can skip
        is_pr = issue.respond_to?(:pull_request) && issue.pull_request.present?
        created_in_range = in_range?(issue.created_at)
        closed_in_range = in_range?(issue.closed_at)
        next unless created_in_range || closed_in_range

        IssueRecord.new(
          number: issue.number,
          title: issue.title,
          state: issue.state,
          user_login: issue.user&.login,
          user_email: nil,
          created_at: issue.created_at,
          closed_at: issue.closed_at,
          pull_request: is_pr
        )
      end
    end
  end
end
