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
      @folio_client ||= Folio::Client.folio_client
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
        url: folio_config['okapi_url'],
        login_params: { 
          username: folio_config['okapi_username'], 
          password: folio_config['okapi_password']
        },
        okapi_headers: { 
          'X-Okapi-Tenant': folio_config['okapi_tenant'], 
          'User-Agent': 'FolioApiClient'
        }
      )
      return @folio_client
    end

    # def Xinitialize(args = {})
    #   return @conn if @conn
    #
    #   folio_config = get_folio_config()
    #
    #   # STANFORD FOLIO OKAPI CLIENT:
    #   @conn = FolioClient.configure(
    #       url: folio_config['okapi_url'],
    #       login_params: { username: folio_config['okapi_username'], password: folio_config['okapi_password'] },
    #       okapi_headers: { 'X-Okapi-Tenant': folio_config['okapi_tenant'], 'User-Agent': 'FolioApiClient' }
    #   )
    #
    #   return @conn
    # end
    #
    #
    # def Xget_folio_config
    #   folio_config = APP_CONFIG['folio']
    #   raise "Cannot find 'folio' config in APP_CONFIG!" if folio_config.blank?
    #   folio_config = HashWithIndifferentAccess.new(folio_config)
    #
    #   [:okapi_url, :okapi_tenant, :okapi_username, :okapi_password].each do |key|
    #     raise "folio config needs value for '#{key}'" unless folio_config.key?(key)
    #   end
    #
    #   return folio_config
    # end
    
    
    def self.get_user_barcode(uni)
      Rails.logger.debug "- Folio::Client.get_user_barcode(uni=#{uni})"
      return nil unless uni.present?
      
      folio_user = get_user_by_uni(uni)
      return nil unless folio_user
      
      # path = '/users?query=(username=="' + uni + '")'
      # Rails.logger.debug "- Folio::Client.get_user_barcode() path=#{path}"
      #
      # @folio_client ||= folio_client
      # folio_response = @folio_client.get(path)
      #
      # first_user = folio_response["users"].first
      # Rails.logger.debug "- Folio::Client.get_user_barcode(#{uni}) first_user: #{first_user}"

      # # barcode lookup should FAIL for inactive users?
      # Or, return whatever barcode we find, let later processes fail
      # active = first_user["active"]
      # return nil unless active
      
      barcode = folio_user["barcode"]
      return barcode

    end
    
    # Given a course-number (registrar number or string with wildcards),
    # Make a courses query, return the FOLIO JSON course list
    def self.get_courses_list_by_course_number(course_number)
      Rails.logger.debug "- Folio::Client.get_courses_list_by_course_number(course_number=#{course_number})"
      return nil unless course_number.present?
      
      path = '/coursereserves/courses?limit=100&query=(courseNumber=="' + course_number + '")'
      Rails.logger.debug "- Folio::Client.get_courses_list_by_course_number() path=#{path}"
      
      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      
      courses_list = folio_response["courses"]
      
      return courses_list
    end


    # Given a course-listing-id (the FOLIO UUID of the course listing object),
    # Lookup the reserves by course-listing-id, return the FOLIO JSON reserves list
    def self.get_reserves_list_by_course_listing_id(course_listing_id)
      # Rails.logger.debug "- Folio::Client.get_reserves_list_by_course_listing_id(course_listing_id=#{course_listing_id})"
      return nil unless course_listing_id.present?
      
      path = '/coursereserves/courselistings/' + course_listing_id + '/reserves?limit=1000'
      Rails.logger.debug "- Folio::Client.get_reserves_list_by_course_listing_id() path=#{path}"

      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      
      reserves_list = folio_response["reserves"]

      return reserves_list
    end
    
    def self.get_item(item_id)
      path = "/item-storage/items/#{item_id}"
      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      return folio_response
    end
    
    # Retrieve a single FOLIO Instance JSON record for a given Voyager Bib ID
    #   {{baseUrl}}/search/instances?query=(hrid="123")&limit=1
    def self.get_instance_by_hrid(hrid)
      query = '(hrid="' + hrid + '")'
      path = "/search/instances?query=#{query}&limit=1"
      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      instances = folio_response['instances']
      if instances.present?
        return instances.first
      else
        return {}
      end
    end

    # Retrieve a single FOLIO Instance JSON record by its UUID
    #   {{baseUrl}}/inventory/instances/{id}
    def self.get_instance_by_id(id)
      path = "/inventory/instances/#{id}"
      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      if folio_response.present?
        return folio_response
      else
        return {}
      end
    end


    # Retrieve a single FOLIO User JSON record for a given Columbia uni
    #   {{baseUrl}}/users?query=(username=="sam119" )&limit=1
    def self.get_user_by_uni(uni)
      query = '(username=="' + uni + '")'
      path = "/users?query=#{query}&limit=1"
      @folio_client ||= folio_client
      folio_response = @folio_client.get(path)
      users = folio_response['users']
      if users.present?
        return users.first
      else
        return {}
      end
    end

    # service_response = Folio::Client.post_item_recall(recall_params)  
    #   {{baseUrl}}/circulation/requests
    def self.post_item_recall(recall_params)
      @folio_client ||= folio_client

      # the error message, if any, is found in different places for different problems
      error_message = nil
      
      begin
        folio_response = @folio_client.post("/circulation/requests", recall_params)
      rescue FolioClient::ValidationError => ex
        message = ex.message.sub(/There was a validation problem with the request: /, '')
        json = JSON.parse(message)
        if json and json["errors"]
          error_message = json["errors"].first["message"]
        else
          error_message = ex.message
        end
      rescue => ex
        error_message = ex.message
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

      return get_blocks_by_user_id( folio_user["id"] )
    end
    

    # FOLIO has two kinds of blocks - automated and manual
    #  {{baseUrl}}/automated-patron-blocks/04354620-5852-54e7-93e5-67b8d374528c
    #  {{baseUrl}}/manualblocks?limit=10000&query=(userId==74b140b4-636a-5476-8312-e0d1d4eaaad5)
    # Fetch both, parse each appropriately, sort/uniq the list, return list of string messages
    def self.get_blocks_by_user_id(user_id)
      return nil unless user_id
      
      @folio_client ||= folio_client

      all_blocks = []

      # Automated
      json_response = @folio_client.get("/automated-patron-blocks/#{user_id}")
      automated_blocks = json_response["automatedPatronBlocks"]
      automated_blocks.each do |block|
        block_message = block["message"]
        all_blocks << block_message unless all_blocks.include?(block_message)
      end

      # Manual
      query = '(userId == ' + user_id + ')'
      json_response = @folio_client.get("/manualblocks?query=#{query}&limit=1000")
      manual_blocks = json_response["manualblocks"]
      manual_blocks.each do |block|
        block_message = block["patronMessage"]
        all_blocks << block_message unless all_blocks.include?(block_message)
      end

      return all_blocks
    end
    
    
    # # /contributor-types/{contributorTypeId}
    # def self.get_contributor_type(contributor_type_id)
    #   path = "/contributor-types/#{contributor_type_id}"
    #   @folio_client ||= folio_client
    #   folio_response = @folio_client.get(path)
    #   return folio_response
    # end
    
    
    
    
    
    

    # This was built on RTAC
    # BUT -- Okapi single-item RTAC is DEPRECATED !!!
    # (and Edge RTAC is broken for multi-holding bibs, and
    # Okapi rtac-batch, called by Edge RTAC, is similarly broken)
    # # Get a simple flat lookup table of item statuses.
    # # Keys are FOLIO item UUIDs, statuses can be any defined item status.
    # # { '0f9e12f8-2839-5235-b7a7-2e3ad5467685': 'Available',
    # #   '3fe71445-aff5-4857-8bc5-f359072432e5': 'Checked out',
    # #   ...etc... }
    # # If the Instance has holdings but no items, return empty: {}
    # def self.get_availability(instance_id)
    #   Rails.logger.debug "- Folio::Client.get_availability(instance_id=#{instance_id})"
    #   return {} unless instance_id.present?
    #
    #   path = '/rtac/' + instance_id
    #   Rails.logger.debug "- Folio::Client.get_availability() path=#{path}"
    #
    #   @folio_client ||= folio_client
    #   begin
    #     folio_response = @folio_client.get(path)
    #   rescue => ex
    #     # Error if, for example, the passed instance uuid does not exist in the tenant
    #     Rails.logger.error "Folio::Client#get_availability(#{instance_id}) error: #{ex.message}"
    #     return {}
    #   end
    #
    #   holdings_list = folio_response['holdings']
    #
    #   availability_hash = {}
    #   holdings_list.each do |holding|
    #     item_id     = holding['id']
    #     item_status = holding['status']
    #     Rails.logger.debug "item_id=#{item_id} item_status=#{item_status}"
    #     availability_hash[item_id] = item_status
    #   end
    #
    #   availability_hash
    # end
    
  end



end



