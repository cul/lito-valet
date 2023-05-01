module Service
  class Starrstor < Service::Base
    # Is the current patron allowed to use the
    # Starrstor offsite request paging service?
    def patron_eligible?(_current_user = nil)
      # For now, any authenticated user may use Starrstor
      true
    end

    # May this bib be requested from Starrstor?
    def bib_eligible?(bib_record = nil)
      # Only records with starrstor holdings
      # which include an available item
      availability ||= bib_record.fetch_voyager_availability

      starrstor_holdings = get_starrstor_holdings(bib_record)
      if starrstor_holdings.size.zero?
        self.error = "This record has no StarrStor holdings.
        <br><br>
        Only items stored in Starr's remote storage facility
        may be requested via StarrStor."
        return false
      end

      available_items = get_available_items(starrstor_holdings, availability)
      return true unless available_items.empty?

      self.error = "This record has no available StarrStor items.
      <br><br>
      All items for this record are either checked our or
      otherwise unavailable."

      false
    end

    def setup_form_locals(params, bib_record, current_user)
      availability ||= bib_record.fetch_voyager_availability
      starrstor_holdings = get_starrstor_holdings(bib_record)
      available_starrstor_items = get_available_items(starrstor_holdings, availability)
      filter_barcode = nil
      if available_starrstor_items.count == 1
        filter_barcode = available_starrstor_items.first[:barcode]
      end
      locals = {
        bib_record: bib_record,
        starrstor_holdings: starrstor_holdings,
        filter_barcode: filter_barcode
      }
      locals
    end

    def send_emails(params, bib_record, current_user)
      mail_params = {
        bib_record: bib_record,
        barcodes:  params[:itemBarcodes],
        patron_uni: current_user.uid,
        patron_email: current_user.email,
        staff_email: @service_config[:staff_email]
      }
      # mail request to staff
      FormMailer.with(mail_params).starrstor_request.deliver_now
      # mail confirm to patron
      FormMailer.with(mail_params).starrstor_confirm.deliver_now
    end

    def get_confirmation_locals(params, bib_record, current_user)
      confirm_locals = {
        bib_record: bib_record,
        barcodes:  params[:itemBarcodes],
        patron_uni: current_user.uid,
        patron_email: current_user.email,
        staff_email: @service_config[:staff_email]
      }
      confirm_locals
    end

    def get_starrstor_holdings(bib_record)
      starrstor_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?( holding[:location_code] )
      end
    end

  end
end
