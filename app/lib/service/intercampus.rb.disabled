module Service
  class Intercampus < Service::Base
    def bib_eligible?(bib_record = nil)
      if bib_record.owningInstitution != 'CUL'
        self.error = 'This is not a Columbia item.
          <br><br>
          Intercampus delivery is only valid for Columbia-owned items.'
        return false
      end

      if bib_record.owningInstitution == 'CUL' &&
         bib_record.onsite_holdings.blank?
        self.error = 'This is Columbia item has no on-campus holdings.
          <br><br>
          Intercampus delivery is only not valid for items stored offsite.'
        return false
      end

      true
    end

    # InterCampus is just a direct bounce
    # to a hardcoded LWeb URL
    def build_service_url(_params, _bib_record, _current_user)
      APP_CONFIG[:intercampus][:bounce_url]
    end
  end
end
