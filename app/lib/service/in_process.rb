module Service
  class InProcess < Service::Base
    # Are any of this bib's holdings in the in_process location?
    def bib_eligible?(bib_record = nil)
      in_process_holdings = get_in_process_holdings(bib_record)
      return true unless in_process_holdings.empty?

      self.error = 'This item has no holdings On Order or In Process.
        <br><br>  Please
        <strong>
        <a href="http://library.columbia.edu/services/askalibrarian.html">
          ask a librarian
        </a>
        </strong>
        or ask for assistance at a service desk.'
      false
    end

    def setup_form_locals(params, bib_record, current_user)
      locals = {
        bib_record: bib_record,
        holdings:   get_in_process_holdings(bib_record)
      }
      locals
    end

    # - mail search details to staff, patron
    def send_emails(params, bib_record, current_user)
      in_process_params = get_in_process_params(params, bib_record, current_user)
      # mail search details to staff, patron
      FormMailer.with(in_process_params).in_process.deliver_now
    end

    # def get_confirm_params(params, bib_record, current_user)
    #   in_process_params = get_in_process_params(params, bib_record, current_user)
    #   confirm_params = {
    #     template: '/forms/in_process_confirm',
    #     locals:   in_process_params
    #   }
    #   confirm_params
    # end

    def get_confirmation_locals(params, bib_record, current_user)
      get_in_process_params(params, bib_record, current_user)
    end

    # Which holdings of this bib are In Process or On Order?
    # - Sometimes found in the MFHD Call Number (852)
    # - Sometimes found in the acquisitions info (894)
    def get_in_process_holdings(bib_record)
      return [] if bib_record.blank? || bib_record.holdings.blank?

      found_holdings = []
      bib_record.holdings.each do |holding|
        call_number = holding[:display_call_number]
        acq_info    = holding[:acquisitions_information].join(' ')

        # We'll need to know this later
        holding[:in_process_flag] = true if
            (call_number.match(/process/i) ||
              acq_info.match(/process/i) ||
              acq_info.match(/received/i))

        found_holdings << holding if
            call_number.match(/order/i) ||
            call_number.match(/process/i) ||
            acq_info.match(/order/i) ||
            acq_info.match(/process/i) ||
            acq_info.match(/received/i)
      end

      found_holdings
    end

    # The same set of params gets used for emails and confirm page
    def get_in_process_params(params, bib_record, current_user)
      #  mfhd_id identifies which Holding the patron is requesting
      holding = bib_record.holdings.select { |h| h[:mfhd_id] == params[:mfhd_id] }.first

      in_process_flag = false

      # staff email will be either to CUL or Barnard, depending
      # on the location.
      staff_email = APP_CONFIG[:in_process][:staff_email]
      if holding[:location_code].match(/bar/i)
        staff_email = APP_CONFIG[:in_process][:barnard_email]
      end

      in_process_params = {
        bib_record:    bib_record,
        location_name: holding[:location_display],
        location_code: holding[:location_code],
        pickup:        params[:pickup],
        note:          params[:note],
        patron_email:  current_user.email,
        staff_email:   staff_email
      }
      in_process_params
    end
  end
end
