# frozen_string_literal: true

require "rails_helper"

RSpec.describe Report, type: :model do
  subject(:report) { build(:report) }

  it { is_expected.to belong_to(:repository).optional }
  it { is_expected.to belong_to(:team).optional }
  it { is_expected.to validate_presence_of(:repository_full_name) }
  it { is_expected.to validate_presence_of(:team_name) }
  it { is_expected.to validate_presence_of(:content) }
  it { is_expected.to validate_inclusion_of(:format).in_array(Report::FORMATS.keys) }

  it "keeps denormalized names when associations are cleared" do
    report = create(:report, repository_full_name: "Acme/app", team_name: "Platform")
    report.update!(repository: nil, team: nil)
    expect(report.reload.repository_full_name).to eq("Acme/app")
    expect(report.team_name).to eq("Platform")
  end

  it "exposes format helpers" do
    html = build(:report, format: "html")
    pdf = build(:report, format: "pdf", filename: "demo.pdf", content: "%PDF-1.4")
    expect(html).to be_html
    expect(html).to be_text_export
    expect(pdf).to be_pdf
    expect(pdf).not_to be_text_export
  end

  it "returns UTF-8 text for content_for_display" do
    report = create(:report, content: "<html>café</html>")
    expect(report.content_for_display.encoding).to eq(Encoding::UTF_8)
    expect(report.content_for_display).to include("café")
  end
end
