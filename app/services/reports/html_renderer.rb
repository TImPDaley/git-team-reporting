# frozen_string_literal: true

module Reports
  # Renders a self-contained HTML document from a metrics payload for archival.
  class HtmlRenderer
    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @payload = payload.deep_stringify_keys
    end

    def call
      ApplicationController.render(
        template: "reports/archived",
        layout: "report_export",
        assigns: { report: payload }
      )
    end

    private

    attr_reader :payload
  end
end
