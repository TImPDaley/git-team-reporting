# frozen_string_literal: true

module Reports
  class MetricsAggregator
    DeveloperMetrics = Data.define(
      :key,
      :display_name,
      :team_member,
      :matched_by,
      :commits,
      :prs_opened,
      :prs_merged,
      :prs_closed_unmerged,
      :reviews,
      :lines_added,
      :lines_deleted,
      :issues_created,
      :issues_closed,
      :pr_cycle_times_hours,
      :commits_as_author,
      :commits_as_committer
    ) do
      def average_pr_cycle_time_hours
        return nil if pr_cycle_times_hours.empty?

        (pr_cycle_times_hours.sum / pr_cycle_times_hours.size.to_f).round(2)
      end

      def matched?
        !team_member.nil?
      end
    end

    ReportMetrics = Data.define(
      :developers,
      :team_totals,
      :repo_totals,
      :unique_contributors,
      :unmatched_contributors
    )

    def self.call(activity:, team_members:)
      new(activity: activity, team_members: team_members).call
    end

    def initialize(activity:, team_members:)
      @activity = activity
      @matcher = DeveloperMatcher.new(team_members)
      @buckets = Hash.new { |h, k| h[k] = blank_bucket(k) }
    end

    def call
      process_commits
      process_pull_requests
      process_reviews
      process_issues

      developers = @buckets.values.map { |bucket| to_metrics(bucket) }
                           .sort_by { |m| [ m.matched? ? 0 : 1, m.display_name.to_s.downcase ] }

      matched = developers.select(&:matched?)
      unmatched = developers.reject(&:matched?)

      ReportMetrics.new(
        developers: developers,
        team_totals: sum_metrics(matched),
        repo_totals: sum_metrics(developers),
        unique_contributors: developers.size,
        unmatched_contributors: unmatched
      )
    end

    private

    attr_reader :activity, :matcher

    def blank_bucket(key)
      {
        key: key,
        team_member: nil,
        matched_by: :unmatched,
        display_name: key,
        commits: 0,
        prs_opened: 0,
        prs_merged: 0,
        prs_closed_unmerged: 0,
        reviews: 0,
        lines_added: 0,
        lines_deleted: 0,
        issues_created: 0,
        issues_closed: 0,
        pr_cycle_times_hours: [],
        commits_as_author: 0,
        commits_as_committer: 0,
        identity_login: nil,
        identity_email: nil,
        identity_name: nil
      }
    end

    def process_commits
      activity.commits.each do |commit|
        author_match = matcher.match(login: commit.author_login, email: commit.author_email)
        bucket = touch_bucket(author_match, login: commit.author_login, email: commit.author_email, name: commit.author_name)
        bucket[:commits] += 1
        bucket[:commits_as_author] += 1
        bucket[:lines_added] += commit.additions.to_i
        bucket[:lines_deleted] += commit.deletions.to_i

        # Track committer separately when different from author
        same_person =
          normalize(commit.author_login) == normalize(commit.committer_login) &&
          normalize(commit.author_email) == normalize(commit.committer_email)

        next if same_person

        committer_match = matcher.match(login: commit.committer_login, email: commit.committer_email)
        committer_bucket = touch_bucket(
          committer_match,
          login: commit.committer_login,
          email: commit.committer_email,
          name: commit.committer_name
        )
        committer_bucket[:commits_as_committer] += 1
      end
    end

    def process_pull_requests
      activity.pull_requests.each do |pr|
        match = matcher.match(login: pr.user_login, email: pr.user_email)
        bucket = touch_bucket(match, login: pr.user_login, email: pr.user_email)

        if pr_created_in_range?(pr)
          bucket[:prs_opened] += 1
        end

        if pr.merged && pr_merged_in_range?(pr)
          bucket[:prs_merged] += 1
          if pr.created_at.present? && pr.merged_at.present?
            hours = ((pr.merged_at - pr.created_at) / 1.hour).to_f
            bucket[:pr_cycle_times_hours] << hours.round(2)
          end
        elsif pr.closed_at.present? && !pr.merged && pr_closed_in_range?(pr)
          bucket[:prs_closed_unmerged] += 1
        end
      end
    end

    def process_reviews
      activity.reviews.each do |review|
        match = matcher.match(login: review.user_login, email: review.user_email)
        bucket = touch_bucket(match, login: review.user_login, email: review.user_email)
        bucket[:reviews] += 1
      end
    end

    def process_issues
      activity.issues.each do |issue|
        next if issue.pull_request

        match = matcher.match(login: issue.user_login, email: issue.user_email)
        bucket = touch_bucket(match, login: issue.user_login, email: issue.user_email)

        if issue_created_in_range?(issue)
          bucket[:issues_created] += 1
        end
        if issue.closed_at.present? && issue_closed_in_range?(issue)
          bucket[:issues_closed] += 1
        end
      end
    end

    def touch_bucket(match, login: nil, email: nil, name: nil)
      bucket = @buckets[match.key]
      bucket[:team_member] ||= match.team_member
      bucket[:matched_by] = match.matched_by if bucket[:matched_by] == :unmatched || match.matched_by != :unmatched
      bucket[:identity_login] ||= login
      bucket[:identity_email] ||= email
      bucket[:identity_name] ||= name
      bucket[:display_name] = display_name_for(bucket)
      bucket
    end

    def display_name_for(bucket)
      if bucket[:team_member]
        bucket[:team_member].display_label
      elsif bucket[:identity_name].present?
        login = bucket[:identity_login]
        login.present? ? "#{bucket[:identity_name]} (@#{login})" : bucket[:identity_name]
      elsif bucket[:identity_login].present?
        "@#{bucket[:identity_login]}"
      elsif bucket[:identity_email].present?
        bucket[:identity_email]
      else
        "Unknown"
      end
    end

    def to_metrics(bucket)
      DeveloperMetrics.new(
        key: bucket[:key],
        display_name: bucket[:display_name],
        team_member: bucket[:team_member],
        matched_by: bucket[:matched_by],
        commits: bucket[:commits],
        prs_opened: bucket[:prs_opened],
        prs_merged: bucket[:prs_merged],
        prs_closed_unmerged: bucket[:prs_closed_unmerged],
        reviews: bucket[:reviews],
        lines_added: bucket[:lines_added],
        lines_deleted: bucket[:lines_deleted],
        issues_created: bucket[:issues_created],
        issues_closed: bucket[:issues_closed],
        pr_cycle_times_hours: bucket[:pr_cycle_times_hours],
        commits_as_author: bucket[:commits_as_author],
        commits_as_committer: bucket[:commits_as_committer]
      )
    end

    def sum_metrics(list)
      {
        commits: list.sum(&:commits),
        prs_opened: list.sum(&:prs_opened),
        prs_merged: list.sum(&:prs_merged),
        prs_closed_unmerged: list.sum(&:prs_closed_unmerged),
        reviews: list.sum(&:reviews),
        lines_added: list.sum(&:lines_added),
        lines_deleted: list.sum(&:lines_deleted),
        issues_created: list.sum(&:issues_created),
        issues_closed: list.sum(&:issues_closed),
        average_pr_cycle_time_hours: average_cycle(list)
      }
    end

    def average_cycle(list)
      hours = list.flat_map(&:pr_cycle_times_hours)
      return nil if hours.empty?

      (hours.sum / hours.size.to_f).round(2)
    end

    def normalize(value)
      value.to_s.strip.downcase
    end

    def range_start
      activity.start_date.beginning_of_day
    end

    def range_end
      activity.end_date.end_of_day
    end

    def in_range?(timestamp)
      return false if timestamp.blank?

      time = timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp.in_time_zone
      time >= range_start && time <= range_end
    end

    def pr_created_in_range?(pr) = in_range?(pr.created_at)
    def pr_merged_in_range?(pr) = in_range?(pr.merged_at)
    def pr_closed_in_range?(pr) = in_range?(pr.closed_at)
    def issue_created_in_range?(issue) = in_range?(issue.created_at)
    def issue_closed_in_range?(issue) = in_range?(issue.closed_at)
  end
end
