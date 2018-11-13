class FormsController < ApplicationController

  # The FormsController handles many different services.
  # Initialize based on active service.
  before_action :initialize_service

  # CUMC staff who have not completed security training
  # may not use authenticated online request services.
  before_action :cumc_block
    
  # Given a bib record id as an 'id' param,
  # Lookup bibliographic information on that bib,
  # Lookup form details in app_config,
  # Either:
  # - build an appropriate form
  # - bounce directly to URL
  def show
    # validate user
    return error("Current user is not elible for service #{@config['label']}") unless patron_eligible?(current_user)
    
    # validate bib record
    bib_id = params['id']
    bib_record = ClioRecord::new_from_bib_id(bib_id)
    return error("Cannot find bib record for id #{bib_id}") if bib_record.blank?
    return error("Bib ID #{bib_id} is not eligble for service #{@config['label']}") unless bib_eligible?(bib_record)

    # process as form or as direct bounce
    case @config['type']
    when 'form'
      return build_form(bib_record)
    when 'bounce'
      return bounce(bib_record)
    else
      return error("No 'type' defined for service #{@config['label']}")
    end

    return error("Valet error: unknown show() failure for service #{@config['label']}")
  end
  
  # form processor
  def create
    bib_id = params['id']
    bib_record = ClioRecord::new_from_bib_id(bib_id)

    # How to best hand-off to service-specific 
    # form processing details?
    # What are common form-processing steps?
    # - sending emails
    # - redirecting the browser
    # - writing to a transaction file? (not-on-shelf)

    # All should log, so that should happen here.
    # (should add service-specific fields)
    log(bib_record, current_user)

    # For now, just send it to the service module
    form_handler(params, bib_record)
  end

  private

  # SERVICE HANDLING
  
  # called in before_action
  def initialize_service
    service = determine_service
    load_service_config(service)
    load_service_module(service)
    authenticate_user! if @config[:authenticate]
  end

  # Original path is something like:  /docdel/123
  # which rails will route to:        /forms/123
  # Recover our service from the original path,
  # store in session
  def determine_service
    original = request.original_fullpath
    return unless original && original.starts_with?('/')
    # '/docdel/123'  ==>  [ '', 'docdel', '123' ]
    service = original.split('/')[1]
  end

  def load_service_config(service)
    Rails.logger.debug "load_service_config() for #{service}..."
    @config = APP_CONFIG[service]
    # store the service key within the config hash
    @config[:service] = service
    return error("Can' find configuration for: #{service}") unless @config.present?
  end
    
  # Dynamically prepend the module methods for the active service
  # so that calling the un-scoped method names, e.g.
  #   build_bounce_url()
  # will call the build_bounce_url() method of the active service.
  def load_service_module(service)
    service_module_name = "Requests::#{service.camelize}"
    Rails.logger.debug "self.class prepend #{service_module_name}"
    service_module = service_module_name.constantize rescue nil
    return error("Cannot load service module for #{@config['label']}") unless service_module.present?
    self.class.send :prepend, service_module_name.constantize
  end
  
  # CUMC staff who have not completed security training
  # may not use authenticated online request services.
  def cumc_block
    return unless current_user && current_user.affils
    return error("Internal error - CUMC Block config missing") unless APP_CONFIG[:cumc]
    if current_user.has_affil(APP_CONFIG[:cumc][:block_affil])
      Rails.logger.info "CUMC block: #{current_user.login}"
      return redirect_to APP_CONFIG[:cumc][:block_url]
    end
  end

  # HELPER METHODS
  
  # Process a 'form' service
  # - setup service-specific local variables for the form
  # - render the service-specific form
  def build_form(bib_record = nil)
    locals = setup_form_locals(bib_record)
    # render @config[:service], locals: {bib_record: bib_record}
    render @config[:service], locals: locals
  end

  # Process a 'bounce' service.
  # - build the bounce URL
  # - log
  # - redirect the user
  def bounce(bib_record = nil)
    bounce_url = build_bounce_url(bib_record)
    if bounce_url.present?
      log(bib_record, current_user)
      Rails.logger.debug "bounce() redirecting to: #{bounce_url}"
      return redirect_to bounce_url
    end

    # Unable to build a bounce URL?  Error!
    return error("Cannot determine bounce url for service #{@config['label']}")
  end

  # DEFAULT LOGGING
  # We'll probably need to support custom logging as well
  def log(bib_record = nil, current_user = nil)
    # basic request data - ip, timestamp, etc.
    data = request_data

    # which log set?
    data.merge!(set: @config['label'])

    # build up logdata for this specific transation
    # - tell about the bib
    logdata = bib_record.basic_log_data
    # - tell about the user
    login = current_user.present? ? current_user.login : ''
    logdata.merge!(user: login)
    # logdata is stored as in JSON
    data.merge!(logdata: logdata.to_json)

    # Log it!  
    begin
      # If logging fails, don't die - report the error and continue
      Log.create(data)
    rescue => ex
      Rails.logger.error "FormsController#bounce error: #{ex.message}"
      Rails.logger.error data.inspect
    end
  end


  # Let caller just do:
  #    if broken() return error("Broken!")
  # instead of multi-line if/end
  def error(message)
    flash.now[:error] = message
    return render :error, layout: 'form_error'
  end
  
  # DEFAULT METHOD IMPLEMENTATIONS
  # They may be overridden in service-specific modules.

  def patron_eligible?(current_user = nil)
    Rails.logger.debug "patron_eligible? - DEFAULT"
    return true
  end
  
  def bib_eligible?(bib_record = nil)
    return true
  end
  
  def setup_form_locals(bib_record = nil)
    locals = { bib_record: bib_record }
    return locals
  end

  
  # COMMON LOGIC
  # Generic methods called by different service modules

  def get_holdings_by_location_code(bib_record = nil, location_code = nil)
    return [] if bib_record.blank? or bib_record.holdings.blank?
    return [] if location_code.blank?

    found_holdings = []
    bib_record.holdings.each do |holding|
      found_holdings << holding if holding[:location_code] == location_code
    end
    return found_holdings
  end

  def get_available_items(holding, availability)
    return [] if holding.blank? || availability.blank?

    available_items = []
    holding[:items].each do |item|
      available_items << item if availability[ item[:item_id] ] == 'Available'
    end
    return available_items
  end
  
  
end


