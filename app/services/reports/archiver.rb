# frozen_string_literal: true

module Reports
  # Persists a generated report with metadata and file content for later viewing.
  class Archiver
    def self.call(result:, date_range:, format: "html", preset: nil)
      new(result: result, date_range: date_range, format: format, preset: preset).call
    end

    def initialize(result:, date_range:, format: "html", preset: nil)
      @result = result
      @date_range = date_range
      @format = format.to_s
      @preset = preset
    end

    def call
      format_meta = Report::FORMATS[format]
      raise ArgumentError, "Unknown report format: #{format}" unless format_meta

      payload = build_payload
      content = render_content(payload)
      extension = format_meta.fetch(:extension)
      stamp = result.generated_at.strftime("%Y%m%d-%H%M%S")
      safe_repo = result.repository.full_name.tr("/", "-")

      Report.create!(
        repository: result.repository,
        team: result.team,
        repository_full_name: result.repository.full_name,
        team_name: result.team.name,
        start_date: date_range.start_date,
        end_date: date_range.end_date,
        date_range_label: date_range.label,
        preset: preset.presence || date_range.try(:preset),
        format: format,
        filename: "#{safe_repo}-#{stamp}.#{extension}",
        content: content,
        metrics_payload: payload,
        generated_at: result.generated_at
      )
    end

    private

    attr_reader :result, :date_range, :format, :preset

    def build_payload
      {
        "repository_id" => result.repository.id,
        "repository_full_name" => result.repository.full_name,
        "team_id" => result.team.id,
        "team_name" => result.team.name,
        "start_date" => date_range.start_date.to_s,
        "end_date" => date_range.end_date.to_s,
        "date_label" => date_range.label,
        "generated_at" => result.generated_at.iso8601,
        "token_source" => result.token_source.to_s,
        "unique_contributors" => result.metrics.unique_contributors,
        "team_totals" => stringify_keys(result.metrics.team_totals),
        "repo_totals" => stringify_keys(result.metrics.repo_totals),
        "developers" => result.metrics.developers.map { |d| serialize_developer(d) },
        "unmatched" => result.metrics.unmatched_contributors.map { |d| serialize_developer(d) }
      }
    end

    def render_content(payload)
      case format
      when "html"
        HtmlRenderer.call(payload: payload)
      when "csv"
        CsvRenderer.call(payload: payload)
      when "markdown"
        MarkdownRenderer.call(payload: payload)
      when "pdf"
        PdfRenderer.call(payload: payload)
      else
        raise ArgumentError, "Unknown report format: #{format}"
      end
    end

    def serialize_developer(dev)
      {
        "key" => dev.key,
        "display_name" => dev.display_name,
        "matched" => dev.matched?,
        "matched_by" => dev.matched_by.to_s,
        "team_member_id" => dev.team_member&.id,
        "commits" => dev.commits,
        "prs_opened" => dev.prs_opened,
        "prs_merged" => dev.prs_merged,
        "prs_closed_unmerged" => dev.prs_closed_unmerged,
        "reviews" => dev.reviews,
        "lines_added" => dev.lines_added,
        "lines_deleted" => dev.lines_deleted,
        "issues_created" => dev.issues_created,
        "issues_closed" => dev.issues_closed,
        "average_pr_cycle_time_hours" => dev.average_pr_cycle_time_hours,
        "commits_as_author" => dev.commits_as_author,
        "commits_as_committer" => dev.commits_as_committer
      }
    end

    def stringify_keys(hash)
      hash.to_h.transform_keys(&:to_s)
    end
  end
end
