# frozen_string_literal: true

class TeamMembersController < ApplicationController
  before_action :set_team
  before_action :set_team_member, only: %i[show edit update destroy]

  def show
  end

  def new
    @team_member = @team.team_members.new
  end

  def create
    @team_member = @team.team_members.new(team_member_params)

    if @team_member.save
      redirect_to @team, notice: "Team member added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @team_member.update(team_member_params)
      redirect_to @team, notice: "Team member updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @team_member.destroy!
    redirect_to @team, notice: "Team member removed."
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def set_team_member
    @team_member = @team.team_members.find(params[:id])
  end

  def team_member_params
    params.require(:team_member).permit(:name, :email, :github_username)
  end
end
