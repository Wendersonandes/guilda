Rails.application.routes.draw do
  devise_for :users

  # Core social — perfil e grupos
  resources :profile_steps, only: [:show, :update]
  resources :actors, only: [ :index, :show ]
  resource :my_profile, path: "my/profile", only: [ :show, :edit, :update ], controller: "profiles"
  resources :profiles, only: [ :index ]
  resources :profiles, only: [ :show ], controller: "actors"
  resources :groups do
    resources :memberships, only: [ :index, :create, :update, :destroy ], controller: "group_memberships" do
      collection do
        get  :insights
        post :approve_request
        post :reject_request
        post :accept_invite
        post :decline_invite
      end
    end
  end

  # Activity stream — feed
  resources :activities, only: [ :index, :show, :new, :create, :destroy ] do
    member do
      get  :flag_form
      post :flag
      post :unflag
    end
    resources :activity_actions, only: [ :create, :destroy ]
    resources :likes, only: [ :create, :destroy ]
    resources :comments, only: [ :create ]
  end

  resources :comments, only: [ :edit, :update, :destroy ] do
    member do
      get  :reply
      get  :flag_form
      post :upvote
      post :downvote
      post :flag
      post :unflag
    end
  end

  get "/c/:short_id", to: "comments#show", as: :comment_permalink

  # Notifications
  resources :notifications, only: [ :index, :update ] do
    collection do
      post :mark_all_as_read
    end
  end

  # Contacts — gerenciamento de conexoes
  resources :contacts, only: [ :index, :create, :destroy ]
  resources :suggestions, only: [ :index ]

  # Account — configuracoes do usuario (singular route -> UsersController)
  resource :account, controller: "users", only: [ :show, :edit, :update ]

  # Admin namespace
  namespace :admin do
    resources :permissions, only: [ :index ]
    resources :ties, only: [ :index, :show ]
    resources :audiences, only: [ :index ]
    resources :roles, only: [ :index, :create, :update ]
  end

  # Locations — dynamic state/city loading
  get "locations/states", to: "locations#states"
  get "locations/cities", to: "locations#cities"

  # Health + Root
  get "up" => "rails/health#show", as: :rails_health_check
  root to: "activities#index"
end
