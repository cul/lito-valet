# Call CLIO-Backend,
# which queries Voyager database for /status and /circ-status
module Clio
  class BackendConnection
    # Lots borrowed from CLIO Spectrum

    # def self.backend_httpclient
    #   hc = HTTPClient.new
    #   # The default is to wait 60/120 seconds - but we expect an instant response,
    #   # anything else means trouble, and we should give up immediately so as not
    #   # to not sit on resources.
    #   hc.connect_timeout = 10 # default 60
    #   hc.send_timeout    = 10 # default 120
    #   hc.receive_timeout = 10 # default 60
    #   hc
    # end

    def self.backend_connection
      backend_config = APP_CONFIG['clio_backend_connection_details']
      unless backend_config.present? && backend_config['url'].present?
        Rails.logger.error 'Missing CLIO Backend config!'
        return {}
      end

      conn = Faraday.new(backend_config['url'], request: {
                           open_timeout: 10, # opening a connection
                           timeout: 10 # waiting for response
                         })
      conn
    end

    def self.get_circ_status(id = nil)
      return {} unless id.present? && id.match(/^\d+$/)

      # backend_config = APP_CONFIG['clio_backend_connection_details']
      # unless backend_config.present? && backend_config['url'].present?
      #   Rails.logger.error "Missing CLIO Backend config!"
      #   return {}
      # end

      # backend_url = backend_config['url'] + '/holdings/circ_status/' + id
      conn = backend_connection
      unless conn
        Rails.logger.error 'CLIO Backend backend_connection() returned nil!'
        return {}
      end
      circ_status_path = '/holdings/circ_status/' + id

      begin
        # json_results = backend_httpclient.get_content(backend_url)
        json_results = conn.get(circ_status_path).body
        backend_results = JSON.parse(json_results).with_indifferent_access
      rescue => ex
        Rails.logger.error "Clio::BackendConnection#circ_status #{ex} URL: #{conn.url_prefix + circ_status_path}"
        return nil
      end

      if backend_results.nil? || backend_results.empty?
        Rails.logger.error "Clio::BackendConnection#circ_status URL: #{conn.url_prefix + circ_status_path} nothing returned"
        return nil
      end

      # data retrieved successfully...
      backend_results
    end

    # Simplify circ_status to just available/unavailable
    # CIRC_STATUS returns:
    # { bib_id: {
    #     holding_id: {
    #       item_id: {
    #         ...
    #         statusCode: 0/1
    #         ...
    #       },
    #       next_item_id: ...
    #     },
    #     next_holding_id...
    #   }
    # }
    # WANTED simplified flattened lookup table:
    #   { item_id: availability, item_id: availability, ...}
    def self.get_bib_availability(id)
      availability_hash = {}
      circ_status = get_circ_status(id)
      return {} unless circ_status.present?
      circ_status[id].each do |holding_id, holding_details|
        Rails.logger.debug "holding_id=#{holding_id}"
        holding_details.each do |item_id, item_details|
          availability = [1, 11].include?(item_details['statusCode']) ? 'Available' : 'Unavailable'
          Rails.logger.debug "item_id=#{item_id} availability=#{availability}"
          availability_hash[item_id] = availability
        end
      end

      availability_hash
    end

    # Called like this:
    #   @voyager_availability = Clio::Backend.get_bib_availability(self.id) || {}
    # Discard
  end
end
