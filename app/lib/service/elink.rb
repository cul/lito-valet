# Just a simple redirect to the ILLiad login page,
# but with Valet authentication and ineligible handling
module Service
  class Elink < Service::Base

    def build_service_url(params, _bib_record, _current_user)

      # The appropriate vendor_endpoint - EBSCO or ProQuest - will be configured in app_config.yml
      vendor_endpoint = @service_config[:vendor_endpoint] 
      Rails.logger.debug "E-Link vendor_endpoint=#{vendor_endpoint}"

      # Remove Rails-generated params, leaving only what was passed in (the OpenURL)
      params.delete('controller')
      params.delete('action')
      Rails.logger.debug "E-Link full params=#{params}"

      # Pass-through all remaining params to the vendor endpoint
      params.permit!
      service_url = "#{vendor_endpoint}?#{params.to_query}"
      Rails.logger.debug "E-Link service_url=#{service_url}"

      return service_url
    end

  end
end

