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
      # illiad_base_url = @service_config[:illiad_base_url]
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      # Pass an OpenURL, rely on Illiad-side logic to select form and map values
      # illiad_url = @service_config[:illiad_openurl_url]
      # illiad_params = get_illiad_params_openurl(bib_record)

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
      # illiad_params['Action']        = '10'
      illiad_params['Form']          = '20'
      illiad_params['Value']         = 'GenericRequestPDD'
      # illiad_params['CitedIn']       = 'https://clio.columbia.edu/catalog/' + bib_record.id
      illiad_params['CitedIn']       = 'CLIO_OPAC-PAGING'
      
      # # Basic params to pass along bibliographic details
      # # Illiad param keys need to match the Illiad form field names
      # illiad_params['LoanTitle']     = bib_record.title
      # illiad_params['LoanAuthor']    = bib_record.author
      # illiad_params['ISSN']          = bib_record.isbn.first
      # illiad_params['CallNumber']    = bib_record.call_number
      # illiad_params['ESPNumber']     = bib_record.oclc_number
      # illiad_params['ItemNumber']    = (bib_record.barcodes.size == 1 ? bib_record.barcodes.first : '')
      # illiad_params['LoanEdition']   = bib_record.edition
      # illiad_params['LoanPlace']     = bib_record.pub_place
      # illiad_params['LoanPublisher'] = bib_record.pub_name
      # illiad_params['LoanDate']      = bib_record.pub_date

      extra_paging_params = Oclc::Illiad.get_paging_params(bib_record)
      illiad_params.merge!(extra_paging_params)
      
      # # LIBSYS-3206 - add Patron Group / Active Barcode
      # illiad_params['ItemInfo2']     = current_user.barcode
      # illiad_params['ItemInfo4']     = current_user.patron_groups.join(',')

      Oclc::Illiad.clean_hash_values(illiad_params)

      return illiad_params
    end

    # UNUSED - replaced with get_illiad_params_explicit()
    # def get_illiad_params_openurl(bib_record)
    #   illiad_params = {}
    #
    #   # Basic params to pass along bibliographic details
    #   illiad_params['title']      = bib_record.title
    #   illiad_params['author']     = bib_record.author
    #   illiad_params['CallNumber'] = bib_record.call_number
    #   illiad_params['isbn']       = bib_record.isbn.first
    #   illiad_params['issn']       = bib_record.issn.first
    #   illiad_params['oclc']       = bib_record.oclc_number
    #   illiad_params['edition']    = bib_record.edition
    #   illiad_params['loanplace']  = bib_record.pub_place
    #   illiad_params['publisher']  = bib_record.pub_name
    #   illiad_params['pub_date']   = bib_record.pub_date
    #
    #   # Extra params related to request processing
    #   illiad_params['sid']        = 'CLIO_OPAC-PAGING'
    #   illiad_params['notes']      = 'https://clio.columbia.edu/catalog/' + bib_record.id
    #   illiad_params['genre']      = 'PDD'
    #
    #   return illiad_params
    # end
    
    # def setup_form_locals(params, bib_record, current_user)
    #   bib_record.fetch_voyager_availability
    #
    #   locals = { bib_record: bib_record }
    #   locals
    # end

    # def send_emails(params, bib_record, current_user)
    #   mail_params = {
    #     bib_record: bib_record,
    #     barcodes:  params[:itemBarcodes],
    #     patron_uni: current_user.uid,
    #     patron_email: current_user.email,
    #     staff_email: @service_config[:staff_email]
    #   }
    #   # mail request to staff
    #   FormMailer.with(mail_params).paging.deliver_now
    # end

    # def get_extra_log_params(params)
    #   call_number = params[:call_number] || ''
    #   callnumber_sortable = Lcsort.normalize(call_number)
    #
    #   extra_log_params = {
    #     barcodes:      params[:itemBarcodes].join('/ '),
    #     callnumber:    call_number,
    #     callnumber_sortable:  callnumber_sortable,
    #     volumne_note:  params[:volume_note],
    #     note:          params[:note],
    #   }
    # end

    # def get_confirmation_locals(params, bib_record, current_user)
    #   confirm_locals = {
    #     bib_record: bib_record,
    #     barcodes:  params[:itemBarcodes],
    #     patron_uni: current_user.uid,
    #     patron_email: current_user.email,
    #   }
    #   confirm_locals
    # end

  end
end

