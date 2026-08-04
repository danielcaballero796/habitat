Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :v1 do
    post :login, to: 'login#login'

    resources :devices do
      resources :device_attributes, only: [:index, :create, :update, :destroy]
    end
  end

  # Session-based auth for the dashboard (separate from JWT API auth above).
  get '/login', to: 'sessions#new', as: :login
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: :logout

  get '/dashboard', to: 'dashboard#index', as: :dashboard

  # NOTE: config.api_only = true (see config/application.rb) makes `resources`
  # exclude :new and :edit by default (API apps don't render HTML forms), so
  # the dashboard's device routes list every action explicitly.
  namespace :dashboard do
    resources :devices, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  end
end
