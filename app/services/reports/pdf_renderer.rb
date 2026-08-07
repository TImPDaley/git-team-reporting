# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Reports
  # Renders a multi-page PDF from a metrics payload using Prawn (no headless browser).
  # Built-in AFM fonts are Windows-1252 only; text is sanitized before drawing.
  class PdfRenderer
    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @data = ExportData.wrap(payload)
    end

    def call
      pdf = Prawn::Document.new(page_size: "LETTER", margin: 36)
      render_header(pdf)
      render_totals(pdf, "Repo totals", data.repo_totals)
      render_totals(pdf, "Team totals (matched members only)", data.team_totals)
      render_developers(pdf)
      pdf.render
    end

    private

    attr_reader :data

    def render_header(pdf)
      pdf.text pdf_safe("Activity report"), size: 11, style: :bold, color: "475569"
      pdf.move_down 4
      pdf.text pdf_safe(data.repository_full_name), size: 18, style: :bold
      pdf.move_down 8
      pdf.text pdf_safe("Team: #{data.team_name}"), size: 10
      pdf.text pdf_safe("Date range: #{data.date_label}"), size: 10
      pdf.text pdf_safe("Generated: #{data.generated_at}"), size: 10
      pdf.text pdf_safe("Unique contributors: #{data.unique_contributors}"), size: 10
      pdf.move_down 16
    end

    def render_totals(pdf, title, totals)
      pdf.text pdf_safe(title), size: 13, style: :bold
      pdf.move_down 6
      rows = [ [ "Metric", "Value" ] ] + data.total_metric_pairs(totals).map { |label, value| [ pdf_safe(label), pdf_safe(value) ] }
      pdf.table(rows, header: true, width: pdf.bounds.width, cell_style: { size: 9, padding: 4 }) do
        row(0).font_style = :bold
        row(0).background_color = "F1F5F9"
      end
      pdf.move_down 14
    end

    def render_developers(pdf)
      pdf.text "By developer", size: 13, style: :bold
      pdf.move_down 6

      headers = compact_headers
      body = data.developers.map { |row| compact_values(row) }
      table_data = [ headers ] + body

      if body.empty?
        pdf.text "No developer activity in this range.", size: 10, color: "64748B"
      else
        pdf.table(table_data, header: true, width: pdf.bounds.width, cell_style: { size: 7, padding: 3 }) do
          row(0).font_style = :bold
          row(0).background_color = "F1F5F9"
          columns(1..-1).align = :right
          column(0).align = :left
        end
      end

      pdf.move_down 8
      pdf.text "* PRs closed without merge.", size: 8, color: "64748B"
    end

    # Wide developer tables need a compact PDF column set.
    def compact_headers
      [
        "Developer", "Match", "Commits", "PRs open", "PRs merged", "PRs closed*",
        "Reviews", "Issues +/-", "Lines +/-", "Cycle (h)"
      ]
    end

    def compact_values(row)
      [
        pdf_safe(row[:display_name]),
        pdf_safe(row[:match_label]),
        cell(row[:commits]),
        cell(row[:prs_opened]),
        cell(row[:prs_merged]),
        cell(row[:prs_closed_unmerged]),
        cell(row[:reviews]),
        "#{cell(row[:issues_created])} / #{cell(row[:issues_closed])}",
        "#{cell(row[:lines_added])} / #{cell(row[:lines_deleted])}",
        cell(row[:average_pr_cycle_time_hours])
      ]
    end

    def cell(value)
      value.nil? ? "" : value.to_s
    end

    # AFM fonts only support Windows-1252; map common Unicode and replace the rest.
    def pdf_safe(value)
      value.to_s
           .gsub(/[\u2013\u2014\u2212]/, "-")
           .gsub(/[\u2018\u2019]/, "'")
           .gsub(/[\u201C\u201D]/, '"')
           .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end
