# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :set_repository, only: %i[show edit update destroy]

  def index
    @repositories = Repository.ordered.includes(:team)
  end

  def show
  end

  def new
    @repository = Repository.new(owner: github_default_owner)
  end

  def create
    @repository = Repository.new(repository_params)

    if @repository.save
      redirect_to @repository, notice: "Repository saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @repository.update(repository_params)
      redirect_to @repository, notice: "Repository updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @repository.destroy!
    redirect_to repositories_path, notice: "Repository deleted."
  end

  private

  def set_repository
    @repository = Repository.find(params[:id])
  end

  def repository_params
    params.require(:repository).permit(:owner, :name, :team_id)
  end
end
