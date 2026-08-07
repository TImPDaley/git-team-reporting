# frozen_string_literal: true

class Report < ApplicationRecord
  FORMATS = {
    "html" => { label: "HTML", mime: "text/html", extension: "html" },
    "csv" => { label: "CSV", mime: "text/csv", extension: "csv" },
    "markdown" => { label: "Markdown", mime: "text/markdown", extension: "md" },
    "pdf" => { label: "PDF", mime: "application/pdf", extension: "pdf" }
  }.freeze

  belongs_to :repository, optional: true
  belongs_to :team, optional: true

  validates :repository_full_name, :team_name, :start_date, :end_date, :format, :filename, :content, :generated_at, presence: true
  validates :format, inclusion: { in: FORMATS.keys }
  validate :end_date_not_before_start_date

  scope :recent_first, -> { order(generated_at: :desc) }

  def format_label
    FORMATS.dig(format, :label) || format.to_s.upcase
  end

  def mime_type
    FORMATS.dig(format, :mime) || "application/octet-stream"
  end

  def html?
    format == "html"
  end

  def pdf?
    format == "pdf"
  end

  def text_export?
    format.in?(%w[html csv markdown])
  end

  # Binary column returns ASCII-8BIT; return scrubbed UTF-8 for text formats.
  def content_for_display
    raw = content
    return raw if raw.nil? || pdf?

    raw.to_s
       .dup
       .force_encoding(Encoding::UTF_8)
       .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
  end

  def date_range_display
    date_range_label.presence || "#{start_date} – #{end_date}"
  end

  def metrics
    metrics_payload.is_a?(Hash) ? metrics_payload : {}
  end

  private

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after start date")
  end
end
