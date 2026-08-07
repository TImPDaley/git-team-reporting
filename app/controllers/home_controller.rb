# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @teams_count = Team.count
    @members_count = TeamMember.count
    @repositories_count = Repository.count
    @reports_count = Report.count
    @recent_reports = Report.recent_first.limit(5)
  end
end
