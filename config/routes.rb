Hyrax::Engine.routes.draw do
  # Downloads controller route
  resources :homepage, only: 'index'

  # Route the home page as the root
  root to: 'homepage#index'

  # Handle routes that existed in Hyrax < 7
  #   e.g. https://scholarsphere.psu.edu/files/gm80hv36p
  get '/files/:id', to: redirect('/concern/generic_works/%{id}')

  resources :downloads, only: :show

  # ResourceSync routes
  get '/.well-known/resourcesync' => 'resource_sync#source_description', as: :source_description
  get '/capabilitylist' => 'resource_sync#capability_list', as: :capability_list
  get '/resourcelist' => 'resource_sync#resource_list', as: :resource_list
  get '/changelist' => 'resource_sync#change_list', as: :change_list

  delete '/uploads/:id', to: 'uploads#destroy', as: :uploaded_file
  post '/uploads', to: 'uploads#create'
  # This is a hack that is required because the rails form the uploader is on
  # sets the _method parameter to patch when the work already exists.
  # Eventually it would be good to update the javascript so that it doesn't
  # submit the form, just the file and always uses POST.
  patch '/uploads', to: 'uploads#create'

  match 'batch_edits/clear' => 'batch_edits#clear', as: :batch_edits_clear, via: [:get, :post]
  resources :batch_edits, only: [:index] do
    member do
      delete :destroy
    end
    collection do
      get :index
      get :edit
      put :update
      delete :clear
      put :state
      put :all
    end
  end
  match 'batch_edits/:id' => 'batch_edits#add', :via => :put
  match 'batch_edits' => 'batch_edits#destroy_collection', :via => :delete

  # Notifications route for catalog index view
  get 'users/notifications_number' => 'users#notifications_number', as: :user_notify
  resources :batch_uploads, only: [:new, :create], controller: 'batch_uploads'

  resources :collections do
    member do
      get 'page/:page', action: :index
      get 'facet/:id', action: :facet, as: :dashboard_facet
    end
    collection do
      put '', action: :update
      put :remove_member
    end
  end

  # File Set routes
  scope :concern do
    resources :file_sets, only: [] do
      resource :fixity_checks, only: [:create]
      member do
        get 'stats'
      end
    end
  end

  resources :files, only: [] do
    member do
      get :citation, controller: :citations, action: :file, as: :citations
      get :stats, controller: :stats, action: :file, as: :stats
    end
  end

  # Generic work routes
  resources :works, only: [] do
    member do
      resources :transfers, as: :work_transfers, only: [:new, :create]
      resource :featured_work, only: [:create, :destroy]
      get :citation, controller: :citations, action: :work, as: :citations
      get :stats, controller: :stats, action: :work, as: :stats
      post 'trophy' => 'trophies#toggle_trophy' # used by hyrax/trophy.js
    end
  end

  # Depositors routes for proxy deposit
  post 'users/:user_id/depositors' => 'depositors#create', as: 'user_depositors'
  delete 'users/:user_id/depositors/:id' => 'depositors#destroy', as: 'user_depositor'

  resources :featured_work_lists, path: 'featured_works', only: :create

  # Messages
  resources :notifications, only: [:destroy, :index] do
    collection do
      delete 'delete_all'
    end
  end

  # User profile
  resources :users, only: [:index, :show] do
    resources :operations, only: [:index, :show], controller: 'operations'
  end

  # Dashboard page
  resource :dashboard, controller: 'dashboard', only: [:show]
  resources :dashboard, only: [] do
    collection do
      get 'activity', action: :activity, as: :dashboard_activity
      resources :transfers, only: [:index, :destroy] do
        member do
          put 'accept'
          put 'reject'
        end
      end
    end
  end

  namespace :dashboard do
    resources :works, only: :index
    resources :collections, only: :index
    resources :profiles, only: [:show, :edit, :update]
  end

  # Routes for user's works, collections, highlights and shares
  # Preserves existing behavior by maintaining paths to /dashboard
  # Routes actions to the various My controllers
  scope :dashboard do
    namespace :my do
      resources :works, only: :index
      get '/works/page/:page', controller: 'works', action: :index
      get 'works/facet/:id', controller: 'works', action: :facet, as: 'dashboard_works_facet'
      resources :collections, only: :index
      get '/collections/page/:page',  controller: 'collections', action: :index
      get '/collections/facet/:id',   controller: 'my/collections', action: :facet, as: 'dashboard_collections_facet'
    end

    get '/highlights',            controller: 'my/highlights', action: :index, as: 'dashboard_highlights'
    get '/highlights/page/:page', controller: 'my/highlights', action: :index
    get '/highlights/facet/:id',  controller: 'my/highlights', action: :facet, as: 'dashboard_highlights_facet'

    get '/shares',            controller: 'my/shares', action: :index, as: 'dashboard_shares'
    get '/shares/page/:page', controller: 'my/shares', action: :index
    get '/shares/facet/:id',  controller: 'my/shares', action: :facet, as: 'dashboard_shares_facet'
  end

  # Contact form routes
  post 'contact' => 'contact_form#create', as: :contact_form_index
  get 'contact' => 'contact_form#new'

  get 'single_use_link/show/:id' => 'single_use_links_viewer#show', as: :show_single_use_link
  get 'single_use_link/download/:id' => 'single_use_links_viewer#download', as: :download_single_use_link
  post 'single_use_link/generate_download/:id' => 'single_use_links#create_download', as: :generate_download_single_use_link
  post 'single_use_link/generate_show/:id' => 'single_use_links#create_show', as: :generate_show_single_use_link
  get 'single_use_link/generated/:id' => 'single_use_links#index', as: :generated_single_use_links
  delete 'single_use_link/:id/delete/:link_id' => 'single_use_links#destroy', as: :delete_single_use_link

  # Permissions routes
  scope :concern do
    resources :permissions, only: [] do
      member do
        get :confirm
        post :copy
        get :confirm_access
        post :copy_access
      end
    end
  end

  # API routes
  if Hyrax.config.arkivo_api?
    namespace :api do
      if defined?(Hyrax::ArkivoConstraint)
        constraints Hyrax::ArkivoConstraint do
          resources :items, except: [:index, :edit, :new], defaults: { format: :json }
        end
      end

      get 'zotero' => 'zotero#initiate', as: :zotero_initiate
      get 'zotero/callback' => 'zotero#callback', as: :zotero_callback
    end
  end

  resources :admin_sets, controller: 'admin_sets'

  namespace :admin do
    resources :admin_sets do
      member do
        get :files
      end
      resource :permission_template
    end
    resources :users, only: [:index]
    resources :permission_template_accesses, only: :destroy
    resource 'stats', only: [:show]
    resources :features, only: [:index] do
      resources :strategies, only: [:update, :destroy]
    end
    resources :workflows
    resources :workflow_roles
    resource :appearance
  end

  resources :content_blocks, only: [] do
    member do
      patch :update
    end
    collection do
      get :edit
    end
  end
  resources :pages, only: [] do
    member do
      patch :update
    end
    collection do
      get :edit
    end
  end
  get 'about' => 'pages#show', id: 'about_page'
  get 'help' => 'pages#show', id: 'help_page'

  # Static page routes
  %w[terms zotero mendeley agreement].each do |action|
    get action, controller: 'static', action: action, as: action
  end
end
