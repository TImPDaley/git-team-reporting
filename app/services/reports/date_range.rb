# frozen_string_literal: true

module Reports
  class DateRange
    PRESETS = {
      "this_week" => "This week",
      "last_week" => "Last week",
      "this_month" => "This month",
      "last_month" => "Last month",
      "custom" => "Custom"
    }.freeze

    Result = Data.define(:start_date, :end_date, :preset, :label)

    def self.resolve(preset:, start_date: nil, end_date: nil, today: Date.current)
      new(preset: preset, start_date: start_date, end_date: end_date, today: today).resolve
    end

    def initialize(preset:, start_date: nil, end_date: nil, today: Date.current)
      @preset = preset.to_s.presence || "this_week"
      @start_date = start_date
      @end_date = end_date
      @today = today
    end

    def resolve
      # Honor filled start/end even if the radio still says a named preset
      # (common form mistake: pick dates but leave "This week" selected).
      effective_preset = custom_dates_provided? ? "custom" : preset

      range =
        case effective_preset
        when "this_week"
          [ today.beginning_of_week, today ]
        when "last_week"
          last = today.prev_week
          [ last.beginning_of_week, last.end_of_week ]
        when "this_month"
          [ today.beginning_of_month, today ]
        when "last_month"
          last = today.prev_month
          [ last.beginning_of_month, last.end_of_month ]
        when "custom"
          custom_range
        else
          raise ArgumentError, "Unknown date range preset: #{preset}"
        end

      Result.new(
        start_date: range[0],
        end_date: range[1],
        preset: effective_preset,
        label: label_for(effective_preset, range[0], range[1])
      )
    end

    private

    attr_reader :preset, :start_date, :end_date, :today

    def custom_dates_provided?
      start_date.present? && end_date.present?
    end

    def custom_range
      start = parse_date(start_date)
      finish = parse_date(end_date)
      raise ArgumentError, "Custom range requires start_date and end_date" if start.blank? || finish.blank?
      raise ArgumentError, "start_date must be on or before end_date" if start > finish

      [ start, finish ]
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error, ArgumentError
      raise ArgumentError, "Invalid date: #{value}"
    end

    def label_for(effective_preset, start, finish)
      "#{PRESETS.fetch(effective_preset, effective_preset)} (#{start} – #{finish})"
    end
  end
end
