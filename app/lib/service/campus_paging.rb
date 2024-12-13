module Service
  class CampusPaging < Service::Base

    # Is the current patron allowed to use the Paging service?
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def build_service_url(params, bib_record, current_user)

      # Explicitly select the form, and explicitly set form field values
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      illiad_full_url = get_illiad_full_url(illiad_base_url, illiad_params)
      
      return illiad_full_url
    end


    private

    def get_illiad_full_url(illiad_base_url, illiad_params)
      illiad_url_with_params = illiad_base_url + '?' + illiad_params.to_query
      
      # Patrons always access Illiad through our CUL EZproxy
      ezproxy_url = APP_CONFIG[:ezproxy_login_url]

      illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params
      
      return illiad_full_url
    end
    
    
    def get_illiad_params_explicit(bib_record, current_user)
      illiad_params = Oclc::Illiad.get_default_params(current_user, bib_record)
      
      # Explicitly tell Illiad which form to use
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

