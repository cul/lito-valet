module Service
  class Bearstor < Service::Base
    # Is the current patron allowed to use the
    # BearStor offsite request paging service?
    def patron_eligible?(_current_user = nil)
      # For now, any authenticated user may use Bearstor
      true
    end

    # May this bib be requested from Bearstor?
    def bib_eligible?(bib_record = nil)
      # Only records with bearstor holdings
      # which include an available item
      availability ||= bib_record.fetch_voyager_availability

      bearstor_holdings = get_bearstor_holdings(bib_record)
      if bearstor_holdings.size.zero?
        self.error = "This record has no BearStor holdings.
        <br><br>
        Only items stored in Barnard's remote storage facility
        may be requested via BearStor."
        return false
      end

      available_items = get_available_items(bearstor_holdings, availability)
      return true unless available_items.empty?

      self.error = "This record has no available BearStor items.
      <br><br>
      All items for this record are either checked our or
      otherwise unavailable."

      false
    end

    def setup_form_locals(params, bib_record, current_user)
      availability ||= bib_record.fetch_voyager_availability
      bearstor_holdings = get_bearstor_holdings(bib_record)
      available_bearstor_items = get_available_items(bearstor_holdings, availability)
      filter_barcode = nil
      if available_bearstor_items.count == 1
        filter_barcode = available_bearstor_items.first[:barcode]
      end
      locals = {
        bib_record: bib_record,
        bearstor_holdings: bearstor_holdings,
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
      FormMailer.with(mail_params).bearstor_request.deliver_now
      # mail confirm to patron
      FormMailer.with(mail_params).bearstor_confirm.deliver_now
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

    def get_bearstor_holdings(bib_record)
      bearstor_location = @service_config[:location_code]
      get_holdings_by_location_code(bib_record, bearstor_location)
    end
  end
end
