
class FormsController < ApplicationController
  # The FormsController handles many different services.
  # Initialize based on active service.
  before_action :initialize_service

  # LIBSYS-4432 - Deprecation of IDMACCESS_ADTO affiliation
  # # CUMC staff who have not completed security training
  # # may not use ANY authenticated online request services.
  # before_action :cumc_block

  # Given a bib record id as an 'id' param,
  # Lookup bibliographic information on that bib,
  # Lookup service configuration details in app_config,
  # Either:
  # - build an appropriate form
  # - bounce directly to URL
  def show

    # short-circuit immediately if the service is in an outage state
    return outage! if @service_config[:outage]

    # If this service requires authentication, then also check that the user is eligible
    if @service_config[:authenticate]
      # - Lookup any FOLIO blocks (fines, recalls, etc.)
      blocks = Folio::Client.get_blocks_by_uni(current_user.uid)
      # - Lookup service-specific eligibility
      service_eligibility = @service.patron_eligible?(current_user)

      # - Either condition prohibits the user from using this request service
      if blocks.present? or (service_eligibility == false)
        # There may be a service-specific message or URL
        return redirect_to(@service_config['ineligible_url']) if @service_config['ineligible_url']
        return error(@service_config['ineligible_message']) if @service_config['ineligible_message']
        # Otherwise, use the default.
        return error("Current user is not elible for service #{@service_config['label']}") 
      end
    end

    # validate bib record
    bib_id = params['id']
    
    # All services require a bib_id, unless they are configured as "bib_optional"
    if bib_id.blank?
      return error("Service #{@service_config['label']} not passed a bib id") unless @service_config['bib_optional']
    end
    
    # If the bib id was passed, then it needs to be a real, valid ID (unless "bib_optional" is set)
    if bib_id.present?
      bib_record = ClioRecord.new_from_bib_id(bib_id)
      if not @service_config['bib_optional']
        return error("Cannot find bib record for id #{bib_id}") if bib_record.blank?
        return error("Bib ID #{bib_id} is not eligble for service #{@service_config['label']}") unless @service.bib_eligible?(bib_record)
      end
    end
        
    # process as form or as direct bounce
    # case @service_config['type']
    case @service.service_type?(bib_record)
    when 'form'
      return build_form(bib_record)
    when 'bounce'
      return bounce(bib_record)
    else
      return error("No 'type' defined for service #{@service_config['label']}")
    end

    return error("Valet error: unknown show() failure for service #{@service_config['label']}")
  end

  # form processor
  # we've collected data from the patron,
  # now create the service request.
  # (which means either redirecting or emailing)
  # possibly land on confirm page.
  def create
    bib_id = params['id']
    bib_record = ClioRecord.new_from_bib_id(bib_id)
    
    # Some services need to do some custom form processing.
    # If they do, stash any result of that processing into 'params'
    service_response = @service.service_form_handler(params)
    return error("Failure processing request!") if service_response.nil?
    params['service_response'] = service_response if service_response

    # All should log, so that should happen here.
    # Some services will pass along extra params from the submission form.
    extra_log_params = @service.get_extra_log_params(params) || {}
    log(bib_record, current_user, extra_log_params)

    # Now that we have user-input params, the service may want to:

    # --- send emails
    @service.send_emails(params, bib_record, current_user)

    # --- redirect browser to an external URL
    redirect_url = @service.build_service_url(params, bib_record, current_user)
    return redirect_to redirect_url if redirect_url.present?

    # --- render a confirmation page
    if template_exists?("forms/#{@service_config[:service_name]}_confirm")
      locals = @service.get_confirmation_locals(params, bib_record, current_user) || {}
      return render("#{@service_config[:service_name]}_confirm", locals: locals)
    end

    # If the service didn't render or redirect??
    return error("Valet error: No confirm page or redirect defined for service #{@service_config['label']}")
  end

  private

  # SERVICE HANDLING

  # called in before_action
  def initialize_service
    Rails.logger.debug("begin initialize_service()")
    service_name = determine_service
    return error('Unable to determine service!') unless service_name
    load_service_config(service_name)

    # If load_service_config() was unable to load @service_config
    return if @service_config.nil? or @service_config.empty?
    
    # If this service is in an outage state, take no further initialization steps!
    return if @service_config[:outage]

    authenticate_user! if @service_config[:authenticate]
    instantiate_service_object(service_name)
    Rails.logger.debug("complete initialize_service()")
  end

  # Original path is something like:  /docdel/123
  # which rails will route to:        /forms/123
  # Recover our service from the original path,
  # store in session
  def determine_service
    # original = request.original_fullpath   # fullpath includes CGI params
    original = request.path
    return unless original && original.starts_with?('/')
    # '/docdel/123'  ==>  [ '', 'docdel', '123' ]
    service = original.split('/')[1]
    service
  end

  def load_service_config(service_name)
    Rails.logger.debug "load_service_config() for #{service_name}..."
    @service_config = APP_CONFIG[service_name]
    return error("Can't find service configuration for: #{service_name}") unless @service_config.present?

    # store the service name within the service config hash
    @service_config[:service_name] = service_name
  end

  # # Dynamically prepend the module methods for the active service
  # # so that calling the un-scoped method names, e.g.
  # #   build_service_url()
  # # will call the build_service_url() method of the active service.
  # def load_service_module(service)
  #   service_module_name = "Service::#{service.camelize}"
  #   Rails.logger.debug "self.class prepend #{service_module_name}"
  #   service_module = service_module_name.constantize rescue nil
  #   return error("Cannot load service module for #{@service_config['label']}") unless service_module.present?
  #   self.class.send :prepend, service_module_name.constantize
  # end

  def instantiate_service_object(service_name)
    service_class_name = "Service::#{service_name.camelize}"
    Rails.logger.debug "instatiating class #{service_class_name}"
    service_class_instance = begin
                               service_class_name.constantize
                             rescue
                               nil
                             end
    return error("Cannot constantize #{service_class_name}") if service_class_instance.nil?
    @service = service_class_instance.new(@service_config)
  end

  # HELPER METHODS

  # Process a 'form' service
  # - setup service-specific local variables for the form
  # - render the service-specific form
  def build_form(bib_record = nil)
    locals = @service.setup_form_locals(params, bib_record, current_user)
    form_name = @service.get_form_name(params, bib_record, current_user)
    render form_name, locals: locals
  end

  # Process a 'bounce' service.
  # - build the bounce URL
  # - log
  # - redirect the user
  def bounce(bib_record = nil)
    bounce_url = @service.build_service_url(params, bib_record, current_user)
    if bounce_url.present?
      log(bib_record, current_user)
      Rails.logger.debug "bounce() redirecting to: #{bounce_url}"
      return redirect_to bounce_url
    end

    # Unable to build a bounce URL?  Error!
    return error("Cannot determine bounce url for service #{@service_config['label']}")
  end

  # DEFAULT LOGGING
  # We'll probably need to support custom logging as well
  def log(bib_record = nil, current_user = nil, extra_log_params = {})
    # basic request data - ip, timestamp, etc.
    data = request_data

    # which log set?
    data[:logset] = @service_config['logset'] || @service_config[:service_name].titleize

    # build up logdata for this specific transation
    logdata = Hash.new
    # - tell about the bib, if there is one for this service request
    logdata.merge!(bib_record.basic_log_data) if bib_record.present?
    # - tell about the user
    login = current_user.present? ? current_user.login : ''
    logdata[:user] = login
    
    # -some services will pass along extra data for the log
    logdata.merge!(extra_log_params) if extra_log_params.present?
    
    # logdata is stored as in JSON
    data[:logdata] = logdata.to_json
    
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
    Rails.logger.debug "ERROR: FormsController.error('#{message}')"
    flash.now[:error] = message
    service_error = begin
                      @service.error
                    rescue
                      ''
                    end
    render :error, locals: { service_error: service_error }
  end

  # Outages may redirect, render custom forms, or custom messasges, or use a default form
  def outage!
    Rails.logger.debug "outage!"
    
    # Redirect to outage URL, if configured
    return redirect_to(@service_config['outage_url']) if @service_config['outage_url']

    # Pass custom outage message, if configured
    locals = { params: params }
    locals[:outage_message] = @service_config['outage_message'].html_safe if @service_config['outage_message']

    # Render custom template, if configured
    return render(@service_config['outage_template'], locals: locals) if @service_config['outage_template']
    
    return render('outage/default_template', locals: locals)
  end

end
