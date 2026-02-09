module Service
  class Precat < Service::Base
    # Are any of this bib's holdings in the precat location?
    def bib_eligible?(bib_record = nil)
      precat_holdings = get_precat_holdings(bib_record)
      return true unless precat_holdings.empty?

      self.error = 'This item is not in Pre-Cataloging status.
        <br><br>  Please
        <strong>
        <a href="http://library.columbia.edu/services/askalibrarian.html">
          ask a librarian
        </a>
        </strong>
        or ask for assistance at a service desk.'
      false
    end

    def setup_form_locals(_params, bib_record, _current_user)
      # We'll want to give lots of info details about the
      # precat holding and it's availability
      precat_holdings = get_precat_holdings(bib_record)
      availability ||= bib_record.fetch_folio_availability
      available_items = get_available_items(precat_holdings.first, availability)
      locals = {
        bib_record: bib_record,
        holding:    precat_holdings.first,
        available:  (available_items.count > 0)
      }
      locals
    end

    # - mail search details to staff, patron
    def send_emails(params, bib_record, current_user)
      precat_params = get_precat_params(params, bib_record, current_user)
      # mail search details to staff, patron
      FormMailer.with(precat_params).precat.deliver_now
    end

    # def get_confirm_params(params, bib_record, current_user)
    #   precat_params = get_precat_params(params, bib_record, current_user)
    #   confirm_params = {
    #     template: '/forms/precat_confirm',
    #     locals:   precat_params
    #   }
    #   confirm_params
    # end

    def get_confirmation_locals(params, bib_record, current_user)
      get_precat_params(params, bib_record, current_user)
    end

    def get_precat_holdings(bib_record)
      precat_location = APP_CONFIG[:precat][:location_code]
      get_holdings_by_location_code(bib_record, precat_location)
    end

    # The same set of params gets used for emails and confirm page
    def get_precat_params(params, bib_record, current_user)
      holding = get_precat_holdings(bib_record).first

      precat_params = {
        bib_record:    bib_record,
        location_name: holding[:location_display],
        location_code: holding[:location_code],
        note:          params[:note],
        patron_email:  current_user.email,
        staff_email:   APP_CONFIG[:precat][:staff_email]
      }
      precat_params
    end
  end
end
