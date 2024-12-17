module Service
  class Ill < Service::Base

    # If a patron has any disqualifying condition (fines, blocks, etc.), 
    # then they'll have a "_blocked" affil, and won't match the permitted_affils list
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def setup_form_locals(params, bib_record, current_user)
      # The ILL service may be called with an OpenURL or with a Bib ID.
      # We need to pass ALL params through the campus-triage form so
      # they can get to the ILL service code.
      locals = { ill_params: params }
      locals
      
    end

    # ILL requests are managed by OCLC ILLiad
    # The Valet ILL service can do many things depending on how it's called: 
    #  (0) If patron's campus == TC
    #      Redirect to Teachers College services web page
    #  (1) /ill
    #      Redirect to ILLiad landing page
    #  (2) /ill/123
    #      Lookup bib metadata, send OpenURL to ILLiad
    #  (3) /ill?Form=99&Author=Smith&Title=Papers (ILLiad form is specified!)
    #      Redirect to ILLiad, to the specific specified form
    #  (4) /ill?Author=Smith&Title=Papers (OpenURL parameters)
    #      Cleanup OpenURL params, send OpenURL to ILLiad
    def build_service_url(params, bib_record, current_user)

      # First, process the campus triage form, bounce TC patrons away immediately
      campus = params['campus']
      return 'https://resolver.library.columbia.edu/tc-ill' if campus == 'tc'

      # Use the campus setting to determine the ILLiad base URL.
      # Either MBUTS (Morningside, etc), or MCC (Medical Campus, ZCH)
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_base_url = APP_CONFIG[:illiad_base_url_zch] if campus == 'MCC'

      # And setup an OpenURL URL, based on the base-url (zcu or zch)
      illad_openurl_url = illiad_base_url + '/OpenURL'

      # Default values that we always want to pass to any ILLiad form
      illiad_params = Oclc::Illiad.get_default_params(current_user, bib_record)

      # Next, cleanup params - afterwards should only hold OpenURL values
      params.delete('campus')
      params.delete('controller')
      params.delete('action')
      params.delete('authenticity_token')
      params.delete('commit')
      # N.B. - the parameter name "action" is ambiguous - it's both an 
      # ILLiad param and a Rails param.  
      # Delete it here, add back in later if needed.

      # (1) Redirect to BorrowDirect Search page, with no arguments
      if bib_record.nil? and params.empty?
        Rails.logger.debug "ill(1): redirect to ILLiad login page"
        return APP_CONFIG[:illiad_login_url] 
      end

      # (2) ILL OpenURL - formed from bib record
      if bib_record.present?
        openurl_bib_params = open_params_from_bib(bib_record)
        illiad_params.merge!(openurl_bib_params)
        # Return the OpenURL url, with our OpenURl params
        return Oclc::Illiad.build_full_url(illad_openurl_url, illiad_params)
      end

      # (3) Redirect to ILLiad, to the specific specified form
      if params.present? and params.has_key?('Form')
        # Action=10 tells Illiad that we'll pass the Form ID to use
        params['Action']    = '10'
        illiad_params.merge!(params)
        # Return the ILLiad base url, with all parameters including Form ID
        return Oclc::Illiad.build_full_url(illiad_base_url, illiad_params)
      end

      # (4) We were passed an OpenURL (without an ILLiad form specifier)
      if params.present? and not params.has_key?('Form')
        params.permit!
        illiad_params.merge!(params)
        # Return the ILLiad base url, with all parameters including Form ID
        return Oclc::Illiad.build_full_url(illad_openurl_url, illiad_params)
      end
      
      # Should never get here!
    end

    
    def open_params_from_bib(bib_record)
      # Not yet implemented
    end

    
  end
end
