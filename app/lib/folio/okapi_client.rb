# 
# FOLIO DOCUMENTATION
#
# Courses and Reserves:
#   https://s3.amazonaws.com/foliodocs/api/mod-courses/r/courses.html
# 

module Folio
  class OkapiClient


    def initialize(args = {})
      return @conn if @conn

      folio_config = get_folio_config()
      
      # STANFORD FOLIO OKAPI CLIENT:
      @conn = FolioClient.configure(
          url: folio_config['okapi_url'],
          login_params: { username: folio_config['okapi_username'], password: folio_config['okapi_password'] },
          okapi_headers: { 'X-Okapi-Tenant': folio_config['okapi_tenant'], 'User-Agent': 'FolioApiClient' }
      )
      
      return @conn
    end


    def get_folio_config
      folio_config = APP_CONFIG['folio']
      raise "Cannot find 'folio' config in APP_CONFIG!" if folio_config.blank?
      folio_config = HashWithIndifferentAccess.new(folio_config)

      [:okapi_url, :okapi_tenant, :okapi_username, :okapi_password].each do |key|
        raise "folio config needs value for '#{key}'" unless folio_config.key?(key)
      end

      return folio_config
    end
    
    
    def get_user_barcode(uni)
      Rails.logger.debug "- Folio::OkapiClient.get_user_barcode(uni=#{uni})"
      return nil unless uni.present?
      
      path = '/users?query=(username=="' + uni + '")'
      Rails.logger.debug "- Folio::OkapiClient.get_user_barcode() path=#{path}"

      folio_response = @conn.get(path)

      first_user = folio_response["users"].first
      Rails.logger.debug "- Folio::OkapiClient.get_user_barcode(#{uni}) first_user: #{first_user}"

      # # barcode lookup should FAIL for inactive users?
      # Or, return whatever barcode we find, let later processes fail
      # active = first_user["active"]
      # return nil unless active
      
      barcode = first_user["barcode"]
      return barcode

    end
    
    # Given a course-number (registrar number or string with wildcards),
    # Make a courses query, return the FOLIO JSON course list
    def get_courses_list_by_course_number(course_number)
      Rails.logger.debug "- Folio::OkapiClient.get_courses_list_by_course_number(course_number=#{course_number})"
      return nil unless course_number.present?
      
      path = '/coursereserves/courses?limit=50&query=(courseNumber=="' + course_number + '")'
      Rails.logger.debug "- Folio::OkapiClient.get_courses_list_by_course_number() path=#{path}"
      
      folio_response = @conn.get(path)
      
      courses_list = folio_response["courses"]
      
      return courses_list
    end


    # Given a course-listing-id (the FOLIO UUID of the course listing object),
    # Lookup the reserves by course-listing-id, return the FOLIO JSON reserves list
    def get_reserves_list_by_course_listing_id(course_listing_id)
      Rails.logger.debug "- Folio::OkapiClient.get_reserves_by_course_listing_id(course_listing_id=#{course_listing_id})"
      return nil unless course_listing_id.present?
      
      path = '/coursereserves/courselistings/' + course_listing_id + '/reserves?limit=100'
      Rails.logger.debug "- Folio::OkapiClient.get_reserves_by_course_listing_id() path=#{path}"

      folio_response = @conn.get(path)
      
      reserves_list = folio_response["reserves"]

      return reserves_list
    end
    
  end



end



