# frozen_string_literal: true

module Reports
  # Normalizes Archiver metrics payloads for CSV / Markdown / PDF exporters.
  class ExportData
    DEVELOPER_COLUMNS = [
      { key: :display_name, header: "Developer" },
      { key: :match_label, header: "Match" },
      { key: :commits, header: "Commits" },
      { key: :prs_opened, header: "PRs opened" },
      { key: :prs_merged, header: "PRs merged" },
      { key: :prs_closed_unmerged, header: "PRs closed unmerged" },
      { key: :reviews, header: "Reviews" },
      { key: :issues_created, header: "Issues created" },
      { key: :issues_closed, header: "Issues closed" },
      { key: :lines_added, header: "Lines added" },
      { key: :lines_deleted, header: "Lines deleted" },
      { key: :average_pr_cycle_time_hours, header: "Avg PR cycle (h)" },
      { key: :commits_as_author, header: "Commits as author" },
      { key: :commits_as_committer, header: "Commits as committer" }
    ].freeze

    TOTAL_KEYS = %w[
      commits prs_opened prs_merged prs_closed_unmerged reviews
      lines_added lines_deleted issues_created issues_closed average_pr_cycle_time_hours
    ].freeze

    TOTAL_LABELS = {
      "commits" => "Commits",
      "prs_opened" => "PRs opened",
      "prs_merged" => "PRs merged",
      "prs_closed_unmerged" => "PRs closed unmerged",
      "reviews" => "Reviews",
      "lines_added" => "Lines added",
      "lines_deleted" => "Lines deleted",
      "issues_created" => "Issues created",
      "issues_closed" => "Issues closed",
      "average_pr_cycle_time_hours" => "Avg PR cycle (h)"
    }.freeze

    def self.wrap(payload)
      new(payload)
    end

    def initialize(payload)
      @payload = payload.deep_stringify_keys
    end

    def repository_full_name
      payload["repository_full_name"].to_s
    end

    def team_name
      payload["team_name"].to_s
    end

    def date_label
      payload["date_label"].presence || "#{payload['start_date']} - #{payload['end_date']}"
    end

    def start_date
      payload["start_date"].to_s
    end

    def end_date
      payload["end_date"].to_s
    end

    def generated_at
      payload["generated_at"].to_s
    end

    def unique_contributors
      payload["unique_contributors"]
    end

    def repo_totals
      totals_hash(payload["repo_totals"])
    end

    def team_totals
      totals_hash(payload["team_totals"])
    end

    def developers
      Array(payload["developers"]).map { |row| developer_row(row) }
    end

    def unmatched
      Array(payload["unmatched"]).map { |row| developer_row(row) }
    end

    def developer_headers
      DEVELOPER_COLUMNS.map { |col| col[:header] }
    end

    def developer_values(row)
      DEVELOPER_COLUMNS.map { |col| format_cell(row[col[:key]]) }
    end

    def total_metric_pairs(totals)
      TOTAL_KEYS.map do |key|
        [ TOTAL_LABELS.fetch(key), format_cell(totals[key.to_sym] || totals[key]) ]
      end
    end

    private

    attr_reader :payload

    def totals_hash(raw)
      hash = (raw || {}).to_h.stringify_keys
      TOTAL_KEYS.each_with_object({}) do |key, acc|
        acc[key.to_sym] = hash[key]
      end
    end

    def developer_row(raw)
      row = raw.to_h.stringify_keys
      matched = ActiveModel::Type::Boolean.new.cast(row["matched"])
      {
        display_name: row["display_name"].to_s,
        match_label: matched ? row["matched_by"].presence || "matched" : "unmatched",
        matched: matched,
        commits: row["commits"],
        prs_opened: row["prs_opened"],
        prs_merged: row["prs_merged"],
        prs_closed_unmerged: row["prs_closed_unmerged"],
        reviews: row["reviews"],
        issues_created: row["issues_created"],
        issues_closed: row["issues_closed"],
        lines_added: row["lines_added"],
        lines_deleted: row["lines_deleted"],
        average_pr_cycle_time_hours: row["average_pr_cycle_time_hours"],
        commits_as_author: row["commits_as_author"],
        commits_as_committer: row["commits_as_committer"]
      }
    end

    def format_cell(value)
      return "" if value.nil?

      value
    end
  end
end
