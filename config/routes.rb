Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :settings, only: %i[ edit update ]
  resources :api_tokens, only: %i[ create destroy ]
  resource :account, only: :destroy do
    get :export
    post :import
  end
  get "privacy", to: "pages#privacy"

  # JSON API for agents and scripts; see docs/api.md.
  namespace :api do
    # Ids must be all digits, so "12abc" doesn't quietly match record 12.
    namespace :v1, defaults: { format: :json }, constraints: { id: /\d+/, gear_id: /\d+/ } do
      get "/", to: "docs#show", as: :docs
      resource :me, only: :show, controller: :me
      resources :gears, only: %i[ index show create update ] do
        resources :expenses, :fuel_entries, :readings, only: %i[ index show create update destroy ]
      end
    end
  end

  resources :gears do
    resources :expenses, except: %i[ index show ]
    resources :readings, except: %i[ index show ]
    resources :fuel_entries, except: %i[ index show ]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "gears#index"
end
