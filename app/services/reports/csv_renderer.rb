# frozen_string_literal: true

require "csv"

module Reports
  # Renders a UTF-8 CSV export from a metrics payload (no Excel BOM).
  class CsvRenderer
    # Spreadsheet formula injection: leading = + - @ (optionally after whitespace).
    FORMULA_DANGEROUS = /\A[\t\r\n ]*[=+\-@]/

    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @data = ExportData.wrap(payload)
    end

    def call
      CSV.generate(force_quotes: false) do |csv|
        csv << sanitize_row([ "Git Team Activity Report" ])
        csv << sanitize_row([ "Repository", data.repository_full_name ])
        csv << sanitize_row([ "Team", data.team_name ])
        csv << sanitize_row([ "Date range", data.date_label ])
        csv << sanitize_row([ "Start date", data.start_date ])
        csv << sanitize_row([ "End date", data.end_date ])
        csv << sanitize_row([ "Generated at", data.generated_at ])
        csv << sanitize_row([ "Unique contributors", data.unique_contributors ])
        csv << []

        csv << sanitize_row([ "Repo totals" ])
        data.total_metric_pairs(data.repo_totals).each { |label, value| csv << sanitize_row([ label, value ]) }
        csv << []

        csv << sanitize_row([ "Team totals (matched members only)" ])
        data.total_metric_pairs(data.team_totals).each { |label, value| csv << sanitize_row([ label, value ]) }
        csv << []

        csv << sanitize_row([ "Developers" ])
        csv << sanitize_row(data.developer_headers)
        data.developers.each { |row| csv << sanitize_row(data.developer_values(row)) }
      end
    end

    private

    attr_reader :data

    def sanitize_row(values)
      values.map { |value| sanitize_field(value) }
    end

    # Prefix a single quote so Excel/Sheets treat the cell as text, not a formula.
    def sanitize_field(value)
      return value if value.nil? || value.is_a?(Numeric)

      string = value.to_s
      return "'#{string}" if string.match?(FORMULA_DANGEROUS)

      string
    end
  end
end
