module Service
  class CampusPaging < Service::Base

    # Is the current patron allowed to use the Paging service?
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = APP_CONFIG[:campus_paging][:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def build_service_url(params, bib_record, current_user)

      # Explicitly select the form, and explicitly set form field values
      # illiad_base_url = APP_CONFIG[:campus_paging][:illiad_base_url]
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      # Pass an OpenURL, rely on Illiad-side logic to select form and map values
      # illiad_url = APP_CONFIG[:campus_paging][:illiad_openurl_url]
      # illiad_params = get_illiad_params_openurl(bib_record)

      illiad_full_url = get_illiad_full_url(illiad_base_url, illiad_params)
      
      return illiad_full_url
    end


    private

    def get_illiad_full_url(illiad_base_url, illiad_params)
      illiad_url_with_params = illiad_base_url + '?' + illiad_params.to_query
      
      # Patrons always access Illiad through our CUL EZproxy
      # ezproxy_url = APP_CONFIG[:campus_paging][:ezproxy_url]
      ezproxy_url = APP_CONFIG[:ezproxy_login_url]

      illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params
      
      return illiad_full_url
    end
    
    
    def get_illiad_params_explicit(bib_record, current_user)
      illiad_params = {}
      
      # Explicitly tell Illiad which form to use
      illiad_params['Action']        = '10'
      illiad_params['Form']          = '20'
      illiad_params['Value']         = 'GenericRequestPDD'
      
      # Basic params to pass along bibliographic details
      # Illiad param keys need to match the Illiad form field names
      illiad_params['LoanTitle']     = bib_record.title
      illiad_params['LoanAuthor']    = bib_record.author
      illiad_params['ISSN']          = bib_record.isbn.first
      illiad_params['CallNumber']    = bib_record.call_number
      illiad_params['ESPNumber']     = bib_record.oclc_number
      illiad_params['ItemNumber']    = (bib_record.barcodes.size == 1 ? bib_record.barcodes.first : '')
      illiad_params['LoanEdition']   = bib_record.edition
      illiad_params['LoanPlace']     = bib_record.pub_place
      illiad_params['LoanPublisher'] = bib_record.pub_name
      illiad_params['LoanDate']      = bib_record.pub_date
      # illiad_params['CitedIn']       = 'https://clio.columbia.edu/catalog/' + bib_record.id
      illiad_params['CitedIn']       = 'CLIO_OPAC-PAGING'
      
      # LIBSYS-3206 - add Patron Group / Active Barcode
      illiad_params['ItemInfo2']     = current_user.barcode
      illiad_params['ItemInfo4']     = current_user.patron_group

      return illiad_params
    end

    def get_illiad_params_openurl(bib_record)
      illiad_params = {}
      
      # Basic params to pass along bibliographic details
      illiad_params['title']      = bib_record.title
      illiad_params['author']     = bib_record.author
      illiad_params['CallNumber'] = bib_record.call_number
      illiad_params['isbn']       = bib_record.isbn.first
      illiad_params['issn']       = bib_record.issn.first
      illiad_params['oclc']       = bib_record.oclc_number
      illiad_params['edition']    = bib_record.edition
      illiad_params['loanplace']  = bib_record.pub_place
      illiad_params['publisher']  = bib_record.pub_name
      illiad_params['pub_date']   = bib_record.pub_date

      # Extra params related to request processing
      illiad_params['sid']        = 'CLIO_OPAC-PAGING'
      illiad_params['notes']      = 'https://clio.columbia.edu/catalog/' + bib_record.id
      illiad_params['genre']      = 'PDD'
      
      return illiad_params
    end
    
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
    #     staff_email: APP_CONFIG[:campus_paging][:staff_email]
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

