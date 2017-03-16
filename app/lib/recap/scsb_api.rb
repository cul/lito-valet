
module Recap
  class ScsbApi

    attr_reader :conn, :scsb_args

    # APP_CONFIG parameter block looks like this:
    # 
    # scsb_connection_details:
    #   api_key: xxx
    #   url: http://foo.bar.com:999
    #   item_availability_path: /blah/itemAvailabilityStatus
    #   search_path: /blah/search
    #   search_by_param_path: /blah/searchByParam

    def self.get_scsb_args
      app_config_key = 'scsb_connection_details'
      scsb_args = APP_CONFIG[app_config_key]
      raise "Cannot find #{app_config_key} in APP_CONFIG!" if scsb_args.blank?
      scsb_args.symbolize_keys!

      [:api_key, :url, :item_availability_path].each do |key|
        raise "SCSB config needs value for '#{key}'" unless scsb_args.has_key?(key)
      end

      @scsb_args = scsb_args
    end

    def self.open_connection(url = nil)
      if @conn
        if url.nil?  || (@conn.url_prefix.to_s == url)
          return @conn
        end
      end

      get_scsb_args
      url ||= @scsb_args[:url]
      Rails.logger.debug "- opening new connection to #{url}"
      @conn = Faraday.new(url: url)
      raise "Faraday.new(#{url}) failed!" unless @conn

      @conn.headers['Content-Type'] = 'application/json'
      @conn.headers['api_key'] = @scsb_args[:api_key]

      return @conn
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
    # availability = Recap::ScsbApi.get_item_availability(barcodes)
    def self.get_item_availability(barcodes = [], conn = nil)
      raise "Recap::ScsbApi.get_item_availability() got blank barcodes" if barcodes.blank?
      Rails.logger.debug "- get_item_availability(#{barcodes})"

      conn ||= open_connection()
      raise "get_item_availability() bad connection [#{conn.inspect}]" unless conn

      get_scsb_args
      path = @scsb_args[:item_availability_path]
      params = {
        barcodes: barcodes
      }

      response = conn.post path, params.to_json
      if response.status != 200
        # Raise or just log error?
        Rails.logger.error "ERROR:  API response status #{response.status}"
        Rails.logger.error "ERROR DETAILS: " + response.body
        return ''
      end

      # parse returned array of item-info hashes into simple barcode->status hash
      response_data = JSON.parse(response.body)
      availabilities = Hash.new
      response_data.each do |item|
        availabilities[ item['itemBarcode'] ] = item['itemAvailabilityStatus']
      end
      return availabilities
    end


    # Return a hash:
    #   { barcode: availability, barcode: availability, ...}
    def self.get_bib_availability(bib_id = nil, institution_id = nil, conn = nil)
      raise "Recap::ScsbApi.get_bib_availability() got nil bib_id" if bib_id.blank?
      raise "Recap::ScsbApi.get_bib_availability() got nil institution_id" if bib_id.blank?
      Rails.logger.debug "- get_bib_availability(#{bib_id}, #{institution_id})"

      conn  ||= open_connection()
      raise "get_bib_availability() bad connection [#{conn.inspect}]" unless conn

      get_scsb_args
      path = @scsb_args[:bib_availability_path]
      params = {
        bibliographicId: bib_id,
        institutionId:   institution_id
      }
      response = conn.post path, params.to_json
      response_data = JSON.parse(response.body)

      if response.status != 200
        # Raise or just log error?
        Rails.logger.error "ERROR:  API response status #{response.status}"
        Rails.logger.error "ERROR DETAILS: " + response_data.to_yaml
        return
      end

      # parse returned array of item-info hashes into simple barcode->status hash
      availabilities = Hash.new
      response_data.each do |item|
        availabilities[ item['itemBarcode'] ] = item['itemAvailabilityStatus']
      end
      return availabilities
    end

  end
end


