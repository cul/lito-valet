module Folio
  class OkapiClient

    attr_reader :conn  #, :folio_config

    def initialize(args = {})
      return @conn if @conn

      folio_config = get_folio_config()
      
      # STANFORD CLIENT:
      @conn = FolioClient.configure(
          url: folio_config['okapi_url'],
          login_params: { username: folio_config['okapi_username'], password: folio_config['okapi_password'] },
          okapi_headers: { 'X-Okapi-Tenant': folio_config['okapi_tenant'], 'User-Agent': 'FolioApiClient' }
      )
      
      return @conn
      
      # LOCAL WORK:
      #
      # okapi_url = folio_config[:okapi_url]
      #
      # # reduce api timeouts - if the endpoint is up, it'll respond quickly.
      # request_params = {
      #   open_timeout: 10, # opening a connection
      #   timeout: 10       # waiting for response
      # }
      #
      # Rails.logger.debug "- opening new connection to #{okapi_url}"
      # @conn = Faraday.new(url: okapi_url, request: request_params)
      # raise "Faraday.new(#{okapi_url}) failed!" unless @conn
      #
      # @conn.headers['Content-Type'] = 'application/json'
      # @conn.headers['X-API-Key'] = folio_config[:api_key]
      #
      # return @conn
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

      folio_users_response = @conn.get(path)

      first_user = folio_users_response["users"].first
      Rails.logger.debug "- Folio::OkapiClient.get_user_barcode(#{uni}) first_user: #{first_user}"
      barcode = first_user["barcode"]
      return barcode

    end



  end



end



