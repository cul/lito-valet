#
#
# Wrapper around Stanford FolioClient
#
# Get a FolioClient with either of:
#   folio_client = Folio::Client.new()
#   folio_client = Folio::Client.folio_client
#
# Call the helper methods defined below:
#   Folio::Client.get_user_by_username('sam119')
#
# Or make direct FOLIO API calls yourself:
#   location_json = Folio::Client.folio_client.get('/locations')
#
module Folio
  class Client
    attr_reader :folio_client

    def initialize
      # @folio_client ||= Folio::Client.folio_client
    end

    def self.get_folio_config
      # app_config should have a FOLIO stanza
      folio_config = APP_CONFIG['folio']
      raise "Cannot find 'folio' config in APP_CONFIG!" if folio_config.blank?

      # Return the entire stanza - whatever it holds
      return folio_config
    end

    def self.folio_client
      folio_config = get_folio_config
      @folio_client = FolioClient.configure(
        url:           folio_config['okapi_url'],
        login_params:  {
          username: folio_config['okapi_username'],
          password: folio_config['okapi_password']
        },
        tenant_id:    folio_config['okapi_tenant'],
        # user_agent:   'FolioApiClient',   # let the gem fill in its default
        timeout: folio_config.key?('okapi_timeout') ? folio_config['okapi_timeout'] : 15
      )
      return @folio_client
    end


    # Network-level failures worth retrying.
    # 4xx/5xx errors from FOLIO, validation errors, or a parse errors are not retried.
    TRANSIENT_ERRORS = [
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      Net::ReadTimeout,
      Net::OpenTimeout,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH
    ].freeze

    # Total attempts (1 initial + 2 retries), and the pause between them.
    RETRY_ATTEMPTS = 3
    RETRY_DELAY = 1

    # Single point for every FOLIO read.
    # Retries transient network failures, then re-raises the last error so the
    # calling method's own rescue decides what to return.
    def self.get_with_retry(path, label = nil)
      label ||= path
      tries = 0
      begin
        tries += 1
        @folio_client ||= folio_client
        @folio_client.get(path)
      rescue *TRANSIENT_ERRORS => e
        if tries < RETRY_ATTEMPTS
          Rails.logger.warn("FOLIO GET #{label} #{e.class} on attempt #{tries}/#{RETRY_ATTEMPTS} - retrying in #{RETRY_DELAY}s")
          sleep RETRY_DELAY
          retry
        end
        Rails.logger.error("FOLIO GET #{label} giving up after #{tries} attempts: #{e.class}")
        raise
      end
    end
    private_class_method :get_with_retry



    def self.get_user_barcode(uni)
      Rails.logger.debug "- Folio::Client.get_user_barcode(uni=#{uni})"
      return nil unless uni.present?

      folio_user = get_user_by_uni(uni)
      return nil if folio_user.blank?

      barcode = folio_user['barcode']
      return nil if barcode.blank?

      return barcode
    rescue StandardError => e
      Rails.logger.error("get_user_barcode(#{uni}) failed: #{e.class}: #{e.message}")
      nil
    end

    # Given a course-number (registrar number or string with wildcards),
    # Make a courses query, return the FOLIO JSON course list
    def self.get_courses_list_by_course_number(course_number)
      Rails.logger.debug "- Folio::Client.get_courses_list_by_course_number(course_number=#{course_number})"
      return nil unless course_number.present?

      path = '/coursereserves/courses?limit=100&query=(courseNumber=="' + course_number + '")'
      Rails.logger.debug "- Folio::Client.get_courses_list_by_course_number() path=#{path}"

      folio_response = get_with_retry(path, "get_courses_list_by_course_number(#{course_number})")

      courses_list = folio_response['courses']

      return courses_list
    rescue StandardError => e
      Rails.logger.error("get_courses_list_by_course_number(#{course_number}) failed: #{e.class}: #{e.message}")
      nil
    end

    # Given a course-listing-id (the FOLIO UUID of the course listing object),
    # Lookup the reserves by course-listing-id, return the FOLIO JSON reserves list
    def self.get_reserves_list_by_course_listing_id(course_listing_id)
      # Rails.logger.debug "- Folio::Client.get_reserves_list_by_course_listing_id(course_listing_id=#{course_listing_id})"
      return nil unless course_listing_id.present?

      path = '/coursereserves/courselistings/' + course_listing_id + '/reserves?limit=1000'
      Rails.logger.debug "- Folio::Client.get_reserves_list_by_course_listing_id() path=#{path}"

      folio_response = get_with_retry(path, "get_reserves_list_by_course_listing_id(#{course_listing_id})")

      reserves_list = folio_response['reserves']

      return reserves_list
    rescue StandardError => e
      Rails.logger.error("get_reserves_list_by_course_listing_id(#{course_listing_id}) failed: #{e.class}: #{e.message}")
      nil
    end

    def self.get_item(item_id)
      path = "/item-storage/items/#{item_id}"
      folio_response = get_with_retry(path, "get_item(#{item_id})")
      return folio_response
    rescue StandardError => e
      Rails.logger.error("get_item(#{item_id}) failed: #{e.class}: #{e.message}")
      nil
    end

    # Retrieve a single FOLIO Instance JSON record for a given Voyager Bib ID
    #   {{baseUrl}}/search/instances?query=(hrid="123")&limit=1
    def self.get_instance_by_hrid(hrid)
      query = '(hrid="' + hrid + '")'
      path = "/search/instances?query=#{query}&limit=1"
      folio_response = get_with_retry(path, "get_instance_by_hrid(#{hrid})")
      instances = folio_response['instances']
      if instances.present?
        return instances.first
      else
        return {}
      end
    rescue StandardError => e
      Rails.logger.error("get_instance_by_hrid(#{hrid}) failed: #{e.class}: #{e.message}")
      {}
    end

    # Retrieve a single FOLIO Instance JSON record by its UUID
    #   {{baseUrl}}/inventory/instances/{id}
    def self.get_instance_by_id(id)
      path = "/inventory/instances/#{id}"
      folio_response = get_with_retry(path, "get_instance_by_id(#{id})")
      if folio_response.present?
        return folio_response
      else
        return {}
      end
    rescue StandardError => e
      Rails.logger.error("get_instance_by_id(#{id}) failed: #{e.class}: #{e.message}")
      {}
    end

    # Retrieve a single FOLIO User JSON record for a given Columbia uni
    #   {{baseUrl}}/users?query=(username=="sam119" )&limit=1
    def self.get_user_by_uni(uni)
      query = '(username=="' + uni + '")'
      path = "/users?query=#{query}&limit=1"
      folio_response = get_with_retry(path, "get_user_by_uni(#{uni})")
      users = folio_response['users']
      if users.present?
        return users.first
      else
        return {}
      end
    rescue StandardError => e
      Rails.logger.error("get_user_by_uni(#{uni}) failed: #{e.class}: #{e.message}")
      nil
    end

    # service_response = Folio::Client.post_item_recall(recall_params)
    #   {{baseUrl}}/circulation/requests
    def self.post_item_recall(recall_params)
      @folio_client ||= folio_client

      # the error message, if any, is found in different places for different problems
      error_message = nil

      begin
        folio_response = @folio_client.post('/circulation/requests', recall_params)
      rescue FolioClient::ValidationError => e
        message = e.message.sub(/There was a validation problem with the request: /, '')
        json = JSON.parse(message)
        if json && json['errors']
          error_message = json['errors'].first['message']
        else
          error_message = e.message
        end
      rescue StandardError => e
        error_message = e.message
      end

      # If any error-message was set in the rescues above, raise an exception for the caller
      raise error_message if error_message

      # Otherwise, pass back whatever was returned from the API call
      return folio_response
    end

    def self.get_blocks_by_uni(uni)
      return nil unless uni

      folio_user = get_user_by_uni(uni)
      return nil unless folio_user

      return get_blocks_by_user_id(folio_user['id'])
    end

    # FOLIO has two kinds of blocks - automated and manual
    #  {{baseUrl}}/automated-patron-blocks/04354620-5852-54e7-93e5-67b8d374528c
    #  {{baseUrl}}/manualblocks?limit=10000&query=(userId==74b140b4-636a-5476-8312-e0d1d4eaaad5)
    # Fetch both, parse each appropriately, sort/uniq the list, return list of string messages
    def self.get_blocks_by_user_id(user_id)
      return nil unless user_id

      all_blocks = []

      # Automated
      json_response = get_with_retry("/automated-patron-blocks/#{user_id}",
                                     "get_blocks_by_user_id(#{user_id}) automated")
      automated_blocks = json_response['automatedPatronBlocks'] || []
      automated_blocks.each do |block|
        block_message = block['message']
        all_blocks << block_message unless all_blocks.include?(block_message)
      end

      # Manual
      query = '(userId == ' + user_id + ')'
      json_response = get_with_retry("/manualblocks?query=#{query}&limit=1000",
                                     "get_blocks_by_user_id(#{user_id}) manual")
      manual_blocks = json_response['manualblocks'] || []
      manual_blocks.each do |block|
        block_message = block['patronMessage']
        all_blocks << block_message unless all_blocks.include?(block_message)
      end

      return all_blocks
    rescue StandardError => e
      Rails.logger.error("get_blocks_by_user_id(#{user_id}) failed: #{e.class}: #{e.message}")
      []
    end

  end

end
