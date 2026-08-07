# frozen_string_literal: true

module Reports
  # Renders a portable GFM Markdown document from a metrics payload.
  class MarkdownRenderer
    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @data = ExportData.wrap(payload)
    end

    def call
      lines = []
      lines << "# Activity report: #{data.repository_full_name}"
      lines << ""
      lines << "- **Team:** #{data.team_name}"
      lines << "- **Date range:** #{data.date_label}"
      lines << "- **Start:** #{data.start_date}"
      lines << "- **End:** #{data.end_date}"
      lines << "- **Generated:** #{data.generated_at}"
      lines << "- **Unique contributors:** #{data.unique_contributors}"
      lines << ""

      lines.concat(section_totals("Repo totals", data.repo_totals))
      lines.concat(section_totals("Team totals (matched members only)", data.team_totals))

      lines << "## By developer"
      lines << ""
      lines << table(
        data.developer_headers,
        data.developers.map { |row| data.developer_values(row) }
      )
      lines << ""
      lines << "_\\* PRs closed without merge are listed as “PRs closed unmerged”._"
      lines << ""

      if data.unmatched.any?
        lines << "## Unmatched contributors"
        lines << ""
        data.unmatched.each do |row|
          lines << "- **#{row[:display_name]}** — commits: #{row[:commits]}, " \
                   "PRs opened: #{row[:prs_opened]}, reviews: #{row[:reviews]}"
        end
        lines << ""
      end

      lines.join("\n")
    end

    private

    attr_reader :data

    def section_totals(title, totals)
      [
        "## #{title}",
        "",
        table(%w[Metric Value], data.total_metric_pairs(totals)),
        ""
      ]
    end

    def table(headers, rows)
      escaped_headers = headers.map { |h| escape_cell(h) }
      lines = []
      lines << "| #{escaped_headers.join(' | ')} |"
      lines << "| #{escaped_headers.map { '---' }.join(' | ')} |"
      rows.each do |row|
        cells = row.map { |cell| escape_cell(cell) }
        lines << "| #{cells.join(' | ')} |"
      end
      lines.join("\n")
    end

    def escape_cell(value)
      value.to_s.gsub("|", "\\|").gsub("\n", " ")
    end
  end
end
