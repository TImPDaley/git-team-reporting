# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Stale browser SW registrations hit this; respond 204 so it does not error-loop.
  get "service-worker", to: proc { [ 204, {}, [ "" ] ] }
  get "service-worker.js", to: proc { [ 204, {}, [ "" ] ] }

  root "home#index"

  resources :teams do
    resources :team_members, path: "members", except: :index
  end

  resources :repositories

  resource :settings, only: %i[show update destroy]

  resources :reports, only: %i[index new create show destroy] do
    member do
      get :download
    end
  end
end
