module Service
  # This service is like Campus-Paging, but for FLI Partnership.
  # It's only valid for FLI holdings (bar,fli and mil,fli),
  # and the only permitted patron affil is SAC.
  class FliPaging < Service::Base

    # Is the current patron allowed to use the Paging service?
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def bib_eligible?(bib_record = nil)
      # Checking location means Valet needs to have it's own list of
      # valid locations, which is redundant w/CLIO's list, which
      # means double-maintentance and risk of getting out-of-sync.

      # But -- we need it for this service.
      # Because we want to list holdings from all valid locations,

      fli_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?( holding[:location_code] )
      end

      return true if fli_holdings.present?

      self.error = "This record has no FLI Partnership holdings.
      <br><br>
      This service is for the request of FLI Partnership materials only."

      return false
    end

    def build_service_url(params, bib_record, current_user)

      # Explicitly select the form, and explicitly set form field values
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      illiad_full_url = Oclc::Illiad.build_full_url(illiad_base_url, illiad_params)
      
      return illiad_full_url
    end


    private

    # def get_illiad_full_url(illiad_base_url, illiad_params)
    #   illiad_url_with_params = illiad_base_url + '?' + illiad_params.to_query
    #
    #   # Patrons always access Illiad through our CUL EZproxy
    #   ezproxy_url = APP_CONFIG[:ezproxy_login_url]
    #
    #   illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params
    #
    #   return illiad_full_url
    # end
    
    
    def get_illiad_params_explicit(bib_record, current_user)
      illiad_params = Oclc::Illiad.get_default_params(current_user, bib_record)
      
      # Explicitly tell Illiad which form to use
      # Action=10 tells Illiad that we'll pass the Form ID to use
      illiad_params['Action']    = '10'
      illiad_params['Form']          = '20'
      illiad_params['Value']         = 'GenericRequestPDD'
      illiad_params['CitedIn']       = 'CLIO_OPAC-PAGING'
      
      extra_paging_params = Oclc::Illiad.get_paging_params(bib_record)
      illiad_params.merge!(extra_paging_params)
      
      Oclc::Illiad.clean_hash_values(illiad_params)

      return illiad_params
    end

  end
end

