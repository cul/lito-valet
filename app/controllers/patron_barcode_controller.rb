class PatronBarcodeController < ApplicationController

  def index
    @config = APP_CONFIG[:patron_barcode]
    return head(:internal_server_error) unless @config && @config[:clients]

    params = patron_barcode_params
    return head(:bad_request) unless params[:uni]
    
    # Find the api key - in the header or the params (params override header)
    api_key = request.headers['X-API-Key']
    api_key = params[:api_key] if params[:api_key]
    return head(:bad_request) unless api_key
    
    # Is the key valid, and valid for this client?
    return head(:unauthorized) unless authorize_client( api_key )     
    
    @uni = params[:uni]
    @patron_barcode = lookup_patron_barcode(@uni)
  end
  
  
  private
  
  def patron_barcode_params
    params.permit(:uni, :api_key, :format)
  end

  def lookup_patron_barcode(uni)
    ils = APP_CONFIG[:ils] || 'voyager'
    return lookup_patron_barcode_voyager(uni) if ils == 'voyager'
    return lookup_patron_barcode_folio(uni) if ils == 'folio'
  end

  
  def lookup_patron_barcode_voyager(uni)
    begin
      oracle_connection ||= Voyager::OracleConnection.new
      patron_id ||= oracle_connection.get_patron_id(uni)
      patron_barcode = oracle_connection.retrieve_patron_barcode(patron_id)
      return patron_barcode
    rescue => ex
      return nil
    end
  end

  def lookup_patron_barcode_folio(uni)
    okapi_client ||= Folio::OkapiClient.new
    patron_barcode = okapi_client.get_user_barcode(uni)
    return patron_barcode

    begin
      okapi_client ||= Folio::OkapiClient.new
      patron_barcode = okapi_client.get_user_barcode(uni)
      return patron_barcode
    rescue => ex
      # TODO - process errors in some way - log, report to client, etc.
      return nil
    end
  end

  
  def authorize_client(api_key)
    # (1) Verify API Key
    # find the client-config block matching the given api key
    client = @config[:clients].select { |client| client[:api_key] == api_key }.first
    return unless client
    
    # (2) Verify client IP
    # IF there's an IP whitelist, test client-ip against the list of approved addresses
    if client[:ips] && client[:ips].count > 0
      whitelisted = client[:ips].any? { |cidr| IPAddr.new(cidr) === request.remote_addr }
      return unless whitelisted
    end

    # If the above tests didn't fail, we're authorized
    return true
  end
  
  
end

