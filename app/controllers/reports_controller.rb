# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :require_github_token!, only: %i[create]
  before_action :set_report, only: %i[show download destroy]

  def index
    @reports = Report.recent_first
  end

  def new
    @repositories = Repository.ordered.includes(:team)
    @default_owner = github_default_owner
    @presets = Reports::DateRange::PRESETS
    @formats = Report::FORMATS
    @report_form = default_form_values
  end

  def create
    @repositories = Repository.ordered.includes(:team)
    @presets = Reports::DateRange::PRESETS
    @formats = Report::FORMATS
    @report_form = report_params.to_h.symbolize_keys

    repository = resolve_repository
    unless repository
      flash.now[:alert] = "Select a saved repository or enter owner and repository name with a team."
      return render :new, status: :unprocessable_entity
    end

    format = (@report_form[:format].presence || "html").to_s
    unless Report::FORMATS.key?(format)
      flash.now[:alert] = "Unknown report format."
      return render :new, status: :unprocessable_entity
    end

    date_range = Reports::DateRange.resolve(
      preset: @report_form[:preset],
      start_date: @report_form[:start_date],
      end_date: @report_form[:end_date]
    )

    config = github_config
    Rails.logger.info(
      "[reports] generating repo=#{repository.full_name} endpoint=#{config.api_endpoint} " \
      "(#{config.api_endpoint_source}) token=#{config.token_source}"
    )

    result = Reports::Generator.call(
      repository: repository,
      start_date: date_range.start_date,
      end_date: date_range.end_date,
      token: config.token,
      token_source: config.token_source,
      api_endpoint: config.api_endpoint
    )

    report = Reports::Archiver.call(
      result: result,
      date_range: date_range,
      format: format,
      preset: date_range.preset
    )

    redirect_to report_path(report), notice: "Report saved. You can reopen it anytime from Reports."
  rescue ArgumentError => e
    render_generate_error(e.message)
  rescue Github::Error => e
    render_generate_error(e.message)
  rescue Faraday::Error, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH => e
    render_generate_error(
      "Could not reach GitHub API at #{github_api_endpoint}. " \
      "Set Settings → API endpoint to https://api.github.com for public GitHub. (#{e.message})"
    )
  rescue Socket::ResolutionError => e
    render_generate_error(
      "DNS lookup failed for the GitHub API host (#{github_api_endpoint}). " \
      "Set Settings → API endpoint to https://api.github.com. (#{e.message})"
    )
  end

  def show
  end

  def download
    # PDFs are binary; text formats are served as UTF-8.
    body = @report.pdf? ? @report.content : @report.content_for_display
    send_data body,
              filename: @report.filename,
              type: @report.mime_type,
              disposition: "attachment"
  end

  def destroy
    @report.destroy!
    redirect_to reports_path, notice: "Report deleted."
  end

  private

  def set_report
    @report = Report.find(params[:id])
  end

  def report_params
    params.require(:report).permit(
      :repository_id,
      :owner,
      :name,
      :team_id,
      :preset,
      :start_date,
      :end_date,
      :format
    )
  end

  def default_form_values
    {
      repository_id: params[:repository_id],
      owner: github_default_owner,
      name: nil,
      team_id: nil,
      preset: "this_week",
      start_date: nil,
      end_date: nil,
      format: "html"
    }
  end

  def resolve_repository
    if @report_form[:repository_id].present?
      return Repository.includes(team: :team_members).find_by(id: @report_form[:repository_id])
    end

    owner = @report_form[:owner].presence
    name = @report_form[:name].presence
    team_id = @report_form[:team_id].presence
    return unless owner && name && team_id

    team = Team.find_by(id: team_id)
    return unless team

    repo = Repository.where("LOWER(owner) = ? AND LOWER(name) = ?", owner.downcase, name.downcase).first
    repo ||= Repository.new(owner: owner, name: name)
    repo.team = team
    repo.owner = owner
    repo.name = name
    repo.save!
    repo
  end


  def render_generate_error(message)
    @repositories = Repository.ordered.includes(:team)
    @presets = Reports::DateRange::PRESETS
    @formats = Report::FORMATS
    @report_form ||= default_form_values
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
