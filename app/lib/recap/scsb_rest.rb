
module Recap
  class ScsbRest
    attr_reader :conn, :scsb_args

    def self.get_scsb_rest_args
      app_config_key = 'rest_connection_details'
      scsb_args = APP_CONFIG['scsb'][app_config_key]
      raise "Cannot find #{app_config_key} in APP_CONFIG!" if scsb_args.blank?

      [:api_key, :url, :item_availability_path].each do |key|
        raise "SCSB config needs value for '#{key}'" unless scsb_args.key?(key)
      end

      @scsb_args = scsb_args
    end

    def self.open_connection(url = nil)
      if @conn
        return @conn if url.nil? || (@conn.url_prefix.to_s == url)
      end

      get_scsb_rest_args
      url ||= @scsb_args[:url]
      Rails.logger.debug "- opening new connection to #{url}"
      
      # reduce api timeouts - if the endpoint is up, it'll respond quickly.
      request_params = { 
        open_timeout: 10, # opening a connection
        timeout: 10       # waiting for response
      }
      @conn = Faraday.new(url: url, request: request_params)
      raise "Faraday.new(#{url}) failed!" unless @conn

      @conn.headers['Content-Type'] = 'application/json'
      @conn.headers['api_key'] = @scsb_args[:api_key]

      @conn
    end

    # NOTE: Currently bibAvailabilityStatus and itemAvailabilityStatus
    # return the same response format:
    # [
    #   {
    #     "itemBarcode": "CU10104704",
    #     "itemAvailabilityStatus": "Available",
    #     "errorMessage": null
    #   },
    #   {
    #     "itemBarcode": "CU10104712",
    #     "itemAvailabilityStatus": "Available",
    #     "errorMessage": null
    #   },
    #   ...
    # ]
    # But the APIs are still under active development.  Response
    # format may diverge in the future.

    # Called like this:
    # scsb_availability = Recap::ScsbRest.get_item_availability(barcodes)
    def self.get_item_availability(barcodes = [], conn = nil)
      raise 'Recap::ScsbRest.get_item_availability() got blank barcodes' if barcodes.blank?
      Rails.logger.debug "- get_item_availability(#{barcodes})"

      conn ||= open_connection
      raise "get_item_availability() bad connection [#{conn.inspect}]" unless conn

      get_scsb_rest_args
      path = @scsb_args[:item_availability_path]
      params = {
        barcodes: barcodes
      }

      response = conn.post path, params.to_json
      if response.status != 200
        # Raise or just log error?
        Rails.logger.error "ERROR:  API response status #{response.status}"
        Rails.logger.error 'ERROR DETAILS: ' + response.body
        return ''
      end

      # parse returned array of item-info hashes into simple barcode->status hash
      response_data = JSON.parse(response.body).with_indifferent_access
      availabilities = {}
      response_data.each do |item|
        availabilities[item['itemBarcode']] = item['itemAvailabilityStatus']
      end
      availabilities
    end

    # Return a hash:
    #   { barcode: availability, barcode: availability, ...}

    # BIB NOT FOUND - Response Code 200, Response Body:
    # [
    #   {
    #     "itemBarcode": "",
    #     "itemAvailabilityStatus": null,
    #     "errorMessage": "Bib Id doesn't exist in SCSB database."
    #   }
    # ]
    def self.get_bib_availability(bibliographicId = nil, institutionId = nil, conn = nil)
      raise 'Recap::ScsbRest.get_bib_availability() got nil bibliographicId' if bibliographicId.blank?
      raise 'Recap::ScsbRest.get_bib_availability() got nil institutionId' if institutionId.blank?
      Rails.logger.debug "- get_bib_availability(#{bibliographicId}, #{institutionId})"

      conn ||= open_connection
      raise "get_bib_availability() bad connection [#{conn.inspect}]" unless conn

      get_scsb_rest_args
      path = @scsb_args[:bib_availability_path]
      params = {
        bibliographicId: bibliographicId,
        institutionId:   institutionId
      }
      Rails.logger.debug "get_bib_availability(#{bibliographicId}) calling SCSB REST API with params #{params.inspect}"
      response = conn.post path, params.to_json
      Rails.logger.debug "SCSB response status: #{response.status}"

      if response.status != 200
        # Raise or just log error?
        Rails.logger.error "ERROR:  API response status #{response.status}"
        Rails.logger.error 'ERROR DETAILS: ' + response.body
        return
      end

      # parse returned array of item-info hashes into simple barcode->status hash
      response_data = JSON.parse(response.body)
      availabilities = {}
      response_data.each do |item|
        if item['errorMessage']
          Rails.logger.error "ERROR: #{item['errorMessage']}"
          next
        end
        availabilities[item['itemBarcode']] = item['itemAvailabilityStatus']
      end
      availabilities
    end

    # # UNUSED
    # def self.get_patron_information(patron_barcode = nil, institution_id = nil, conn = nil)
    #   raise # UNUSED
    #   raise "Recap::ScsbRest.get_patron_information() got blank patron_barcode" if patron_barcode.blank?
    #   raise "Recap::ScsbRest.get_patron_information() got blank institution_id" if institution_id.blank?
    #   Rails.logger.debug "- get_patron_information(#{patron_barcode}, #{institution_id})"
    #
    #   conn  ||= open_connection()
    #   raise "get_bib_availability() bad connection [#{conn.inspect}]" unless conn
    #
    #   get_scsb_rest_args
    #   path = @scsb_args[:patron_information_path]
    #   params = {
    #     patronIdentifier:      patron_barcode,
    #     itemOwningInstitution: institution_id
    #   }
    #   response = conn.post path, params.to_json
    #
    #   if response.status != 200
    #     # Raise or just log error?
    #     Rails.logger.error "ERROR:  API response status #{response.status}"
    #     Rails.logger.error "ERROR DETAILS: " + response.body
    #   end
    #
    #   # Rails.logger.debug "response.body=\n#{response.body}"
    #   patron_information_hash = JSON.parse(response.body).with_indifferent_access
    #   # Just return the full hash, let the caller pull out what they want
    #   return patron_information_hash
    # end

    def self.request_item(params, conn = nil)
      # Build SCSB-specific params from Valet application params
      request_item_params = build_request_item_params(params)

      # Do we want to check params to see if what we need is in there?
      Rails.logger.debug "- request_item(#{request_item_params.inspect})"

      conn ||= open_connection
      raise "request_item() bad connection [#{conn.inspect}]" unless conn

      get_scsb_rest_args
      path = @scsb_args[:request_item_path]
      response = conn.post path, request_item_params.to_json

      if response.status != 200
        # A SCSB-side error might look something like this:
        # response.status: 500
        # response.body: {
        #   "timestamp":1502041272960,
        #   "status":500,
        #   "error":"Internal Server Error",
        #   "exception":"org.springframework.web.client.ResourceAccessException",
        #   "message":"I/O error on POST request for \"http://172.31.4.217:9095/requestItem/validateItemRequest\": Connection refused; nested exception is java.net.ConnectException: Connection refused","path":"/requestItem/requestItem"
        # }

        # Log error, trust caller to look into response hash to do the right thing
        Rails.logger.error "ERROR:  API response status #{response.status}"
        Rails.logger.error 'ERROR DETAILS: ' + response.body
      end

      # Rails.logger.debug "response.body=\n#{response.body}"
      response_hash = JSON.parse(response.body).with_indifferent_access
      # Just return the full hash, let the caller pull out what they want
      response_hash
    end
    
    # SCSB requests only need a specific set of values
    def self.build_request_item_params(params)
      request_item_params = Hash.new()
      
      # Simple strings fields that we want copied from Valet into SCSB request params,
      # some apply only to EDD, some apply to physical delivery
      @simple_fields = [
        "author",
        "bibId",    # LIBSYS-5508 - maybe should be cleaned up?
        "callNumber",
        "chapterTitle",
        "deliveryLocation",
        "emailAddress",
        "endPage",
        # "id",    # LIBSYS-5508 - unnecessary, and may be breaking requests
        "issue",
        "itemBarcodes",
        "itemOwningInstitution",
        "patronBarcode",
        "requestNotes",
        "requestType",
        "requestingInstitution",
        "startPage",
        "titleIdentifier",
        # "trackingId",     # NYPL-specific ?
        # "username",       # Unnecessary
        "volume",
      ]
      @simple_fields.each do |field|
        # Skip empty fields
        next unless params[field]

        request_item_params[field] = params[field] || ''
      end
      
      request_item_params
    end
    
  end
end
