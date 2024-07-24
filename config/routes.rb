Rails.application.routes.draw do
  match '/404', to: 'errors#not_found', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all

  root 'welcome#index'
  get 'welcome/index'
  get 'welcome/logout'

  get '/timeout', to: 'welcome#timeout'

  devise_for :users, controllers: { sessions: 'users/sessions', omniauth_callbacks: 'users/omniauth_callbacks' }

  devise_scope :user do
    get 'sign_in', to: 'users/sessions#new', as: :new_user_session
    get 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  # special admin pages
  get 'admin/system'
  get 'admin/request_services'

  # all requests generate logs
  resources :logs do
    collection do
      # bounce the user to another URL, and log it
      get 'bounce'
      # # List known log sets
      # get 'sets'
    end
  end

  # === SIMPLE BIB SERVICES ===
  # Valet maps all these requests to the Forms Controller,
  # with each path mapping to a key in app_config.yml
  # - incoming links to /docdel/123 map to #show, with bibkey 123,
  # - #show method builds a form based on bibkey 123 which posts to #create,
  # - #create, the form-handler - logs, emails, bounces, etc.
  resources :campus_paging,
            :campus_paging_pilot,
            :fli_paging,
            :campus_scan,
            :borrow_direct,
            :ill_scan,
            # :intercampus,
            :in_process,
            :precat,
            :item_feedback,
            :notonshelf,
            :bearstor,
            :avery_onsite,
            :starrstor,
            # Faux services to aid in testing and demonstration
            :outage_redirect_example,
            :outage_message_example,
            :outage_template_example,
            :outage_default_example,
        controller: 'forms',
        only: [:show, :create]



  # === SIMPLE REDIRECT SERVICES ===
  # These services take no arguments.
  # They authenticate, log, and then redirect only.
  # [n.b., these lines must come AFTER simple-bib services in routes.rb,
  #  for precedence order for borrow_direct#show with and without an :id ]
  get 'borrow_direct', action: :show, controller: 'forms'
  get 'illiad', action: :show, controller: 'forms'



  # === NOT-SO-SIMPLE SERVICES ===
  # These services require extra information beyond the bib key

  # ----- BIB+HOLDING SERVICES -----
  # The ReCAP services act upon a specific holding within a specific bib,
  # so they need both args passed in, like so:
  #     https://valet.cul.columbia.edu/recap_loan/2929292/10086
  #     https://valet.cul.columbia.edu/recap_scan/2929292/10086

  # Here's the routing magic to generate the correct bound routes:
  get 'recap_loan/:id(/:mfhd_id)', action: :show, controller: 'forms', as: 'recap_loan'
  get 'recap_scan/:id(/:mfhd_id)', action: :show, controller: 'forms', as: 'recap_scan'
  # Here are the regular POST routes
  resources :recap_loan, 
            :recap_scan, 
            controller: 'forms',
            only: [:create]


  # === ARBITRARY SERVICES ===
  #
  #   "Let's use Valet for this!"
  #
  resources :patron_barcode, only: [:index]



  # === OLD CRUD BELOW ===

  # Offsite currently has custom code
  resources :offsite_requests do
    collection do
      # different entry points to the request workflow
      get 'bib'
      get 'holding'
      get 'barcode'

      # exception conditions
      get 'ineligible'
      get 'error'
    end
  end

  # OLD first-generation approach to logfiles
  get 'admin/logs'
  get 'admin/log_file'

end

