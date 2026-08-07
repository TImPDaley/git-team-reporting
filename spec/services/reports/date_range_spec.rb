# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::DateRange do
  let(:today) { Date.new(2026, 8, 5) } # Wednesday

  it "resolves this week from beginning of week through today" do
    result = described_class.resolve(preset: "this_week", today: today)
    expect(result.start_date).to eq(Date.new(2026, 8, 3))
    expect(result.end_date).to eq(today)
  end

  it "resolves last week" do
    result = described_class.resolve(preset: "last_week", today: today)
    expect(result.start_date).to eq(Date.new(2026, 7, 27))
    expect(result.end_date).to eq(Date.new(2026, 8, 2))
  end

  it "resolves this month" do
    result = described_class.resolve(preset: "this_month", today: today)
    expect(result.start_date).to eq(Date.new(2026, 8, 1))
    expect(result.end_date).to eq(today)
  end

  it "resolves last month" do
    result = described_class.resolve(preset: "last_month", today: today)
    expect(result.start_date).to eq(Date.new(2026, 7, 1))
    expect(result.end_date).to eq(Date.new(2026, 7, 31))
  end

  it "resolves a custom range" do
    result = described_class.resolve(
      preset: "custom",
      start_date: "2026-07-01",
      end_date: "2026-07-15",
      today: today
    )
    expect(result.start_date).to eq(Date.new(2026, 7, 1))
    expect(result.end_date).to eq(Date.new(2026, 7, 15))
    expect(result.preset).to eq("custom")
    expect(result.label).to include("Custom")
  end

  it "uses filled start/end dates even when another preset radio is selected" do
    result = described_class.resolve(
      preset: "this_week",
      start_date: "2026-01-01",
      end_date: "2026-07-31",
      today: today
    )
    expect(result.start_date).to eq(Date.new(2026, 1, 1))
    expect(result.end_date).to eq(Date.new(2026, 7, 31))
    expect(result.preset).to eq("custom")
  end

  it "requires both dates for a custom preset" do
    expect {
      described_class.resolve(preset: "custom", start_date: "2026-07-01", end_date: nil, today: today)
    }.to raise_error(ArgumentError, /requires start_date and end_date/)
  end

  it "rejects an inverted custom range" do
    expect {
      described_class.resolve(preset: "custom", start_date: "2026-07-15", end_date: "2026-07-01", today: today)
    }.to raise_error(ArgumentError, /on or before/)
  end
end
