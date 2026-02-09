module Service
  class AveryOnsite < Service::Base
    # For the ReCAP services, use the offsite_elibible? logic from User model
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
      # and want to OMIT holdings from any non-avery-onsite location

      avery_onsite_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?(holding[:location_code])
      end

      return true if avery_onsite_holdings.present?

      self.error = "This record has no Avery holdings.
      <br><br>
      This service is for the request of Avery materials only."

      return false
    end

    def setup_form_locals(params, bib_record, current_user)
      avery_onsite_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?(holding[:location_code])
      end

      # If there's only one holding with only one item, pre-select that item
      filter_barcode = nil
      if avery_onsite_holdings.size == 1
        if avery_onsite_holdings.first[:items].size == 1
          filter_barcode = avery_onsite_holdings.first[:items].first[:barcode]
        end
      end

      # Many Avery holdings have no item records.
      # That's ok, but we'll want to know in advance.
      total_item_count = 0
      avery_onsite_holdings.each do |holding|
        total_item_count = total_item_count + holding[:items].size
      end

      locals = {
        bib_record:       bib_record,
        holdings:         avery_onsite_holdings,
        filter_barcode:   filter_barcode,
        total_item_count: total_item_count
      }
    end

    def send_emails(params, bib_record, current_user)
      avery_onsite_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?(holding[:location_code])
      end

      requested_items = []
      avery_onsite_holdings.each do |holding|
        holding[:items].each do |item|
          item[:holding] = holding
          requested_items << item if (params[:itemBarcodes] && params[:itemBarcodes].include?(item[:barcode]))
        end
      end

      # If the holding has no items (which happens in Avery), we
      # create a faux item, to pass data to the location
      if requested_items.size == 0
        faux_item = { holding: avery_onsite_holdings.first }
        requested_items = [ faux_item ]
      end

      mail_params = {
        bib_record:      bib_record,
        requested_items: requested_items,
        patron_uni:      current_user.uid,
        patron_email:    current_user.email,
        visitDate:       params[:visitDate],
      }
      # mail request to staff
      FormMailer.with(mail_params).avery_onsite_request.deliver_now
      # # mail confirm to patron
      FormMailer.with(mail_params).avery_onsite_confirm.deliver_now
    end
  end
end
