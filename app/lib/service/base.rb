module Service
  class Base
    attr_accessor :error

    def initialize(config)
      @service_config = config
    end

    # DEFAULT METHOD IMPLEMENTATIONS
    # They may be overridden in service-specific modules.
    def service_type?(_bib_record = nil)
      service_type = @service_config[:type]
      return service_type
    end

    def patron_eligible?(_current_user = nil)
      Rails.logger.debug 'patron_eligible? - DEFAULT'
      true
    end

    def bib_eligible?(_bib_record = nil)
      true
    end

    def build_service_url(_params, _bib_record, _current_user)
      nil
    end

    def setup_form_locals(_params, bib_record = nil, _current_user)
      locals = { bib_record: bib_record }
      locals
    end

    # By default render a form with the same name as the service.
    # But individual services may override this with custom logic to
    # branch to different forms if appropriate.
    def get_form_name(_params, _bib_record, _current_user)
      form_name = @service_config[:service_name]
      return form_name
    end

    # Forms Controller manages redirects, emails, and confirms.
    # If the service needs to do any form-param processing before all that,
    # they can override this method.
    def service_form_handler(_params)
      {}
    end

    # do nothing?
    # def get_confirmation_locals(_params, _bib_record, _current_user)
    #   {}
    # end

    # or always do the default?
    def get_confirmation_locals(params, bib_record, _current_user)
      confirm_locals = {
        params:     params,
        bib_record: bib_record
      }
      confirm_locals
    end

    def get_extra_log_params(_params = nil)
      {}
    end

    def send_emails(_params, _bib_record, _current_user)
      nil
    end

    # COMMON LOGIC
    # Generic methods called by different service modules

    def get_holdings_by_location_code(bib_record = nil, location_code = nil)
      return [] if bib_record.blank? || bib_record.holdings.blank?
      return [] if location_code.blank?

      found_holdings = []
      bib_record.holdings.each do |holding|
        found_holdings << holding if holding[:location_code] == location_code
      end
      found_holdings
    end

    # Accept either a single holding or an array of holdings,
    # return an array of all available items within the holding(s).
    def get_available_items(holding, availability)
      return [] if holding.blank? || availability.blank?

      available_items = []
      Array.wrap(holding).each do |each_holding|
        each_holding[:items].each do |item|
          available_items << item if availability[item[:item_id]] == 'Available'
        end
      end
      available_items
    end
  end
end
