module Service
  class RecapScan < Service::Base

    # For the ReCAP services, use the offsite_elibible? logic from User model
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    # May this bib be requested from Offsite?
    def bib_eligible?(bib_record = nil)
      bib_record.offsite_holdings.size > 0
    end

    # def setup_form_locals(params, bib_record, current_user)
    #   # find the holding being requested
    #   target_holding = bib_record.holdings.select do |holding|
    #     holding[:mfhd_id] == params[:mfhd_id]
    #   end.first
    #
    #   # form has special handling for zero-available-items
    #   available_count = 0
    #   target_holding[:items].each do |item|
    #     available_count += 1 if (bib_record.fetch_scsb_availabilty[item[:barcode]] == 'Available')
    #   end
    #
    #   # pass along the bib and the holding being requested
    #   locals = {
    #     bib_record: bib_record,
    #     holding: target_holding,
    #     available_count: available_count
    #   }
    #   locals
    # end

    def get_form_name(params, bib_record, current_user)
      # We need to know the holding id to build the default form
      default_form_name = @service_config[:service_name]

      # We already know the holding id if:
      # - there's a mfhd_id in the params, or 
      return default_form_name if params[:mfhd_id]
      # - there's only a single offsite holding
      return default_form_name if bib_record.offsite_holdings.size == 1

      # But if we don't know the holding, ask for it, 
      # using a special "holdings" form...
      return "#{default_form_name}_holdings"
    end

    # this method needs to setup form locals for 
    # EITHER holdings-selection form OR item-selection form
    def setup_form_locals(params, bib_record, current_user)
      # identify the target holding for item-selection form
      # (or leave nil for holding-selection form)
      target_holding = nil
      
      if params[:mfhd_id]
        target_holding = bib_record.holdings.select do |holding|
          holding[:mfhd_id] == params[:mfhd_id]
        end.first
      end

      if target_holding.nil? && bib_record.offsite_holdings.size == 1
        target_holding = bib_record.offsite_holdings.first
      end
      
      # item-selection form has special handling for zero-available-items
      available_count = 0

      if target_holding
        target_holding[:items].each do |item|
          available_count += 1 if (bib_record.fetch_scsb_availabilty[item[:barcode]] == 'Available')
        end
      end

      # pass along the bib and the holding being requested
      locals = {
        bib_record: bib_record,
        holding: target_holding,
        available_count: available_count
      }
      locals
    end


    # Service-specific form-param handling, before any email or confirm screen.
    # For ReCAP services, this is where the actual SCSB API request is made.
    def service_form_handler(params)
      service_response = Recap::ScsbRest.request_item(params)
    end


    # Basic request data (bib, user, datestamp, IP) is automatically logged.
    # Services may return a hash of additional data to be logged.
    def get_extra_log_params(params)
      extra_log_params = {}
      
      extra_log_params['patronBarcode'] = params['patronBarcode']
      extra_log_params['emailAddress'] = params['emailAddress']
      
      success = params['service_response']['success'] ||  params['service_response']['error'] || 'false'
      extra_log_params['success'] = success

      screenMessage = params['service_response']['screenMessage'] ||  params['service_response']['message'] || ''
      extra_log_params['screenMessage'] = screenMessage

      extra_log_params['requestType'] = params['requestType']

      extra_log_params['itemOwningInstitution'] = params['itemOwningInstitution']
      extra_log_params['itemBarcodes'] = Array(params['itemBarcodes']).join(' / ')
      extra_log_params['callNumber'] = params['callNumber']

      extra_log_params
    end
    
    def send_emails(params, bib_record, current_user)
      # Call recap_scan_confirm() method of /app/mailers/form_mailer.rb
      # Pass along all our params to be used in email subject and 
      # email body template (views/form_mailer/recap_scan_confirm.text.erb)
      FormMailer.with(params).recap_scan_confirm.deliver_now
    end
    
    # The ReCAP services will give the patrons a confirmation screen,
    # so they need to define a locals hash for the template
    def get_confirmation_locals(params, bib_record, current_user)
      confirm_locals = {
        params: params
        # bib_record: bib_record,
        # barcodes:  params[:itemBarcodes],
        # patron_uni: current_user.uid,
        # patron_email: current_user.email,
        # staff_email: APP_CONFIG[:SERVICE][:staff_email]
      }
      confirm_locals
    end


  end
end
