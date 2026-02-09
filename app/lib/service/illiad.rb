# Just a simple redirect to the ILLiad login page,
# but with Valet authentication and ineligible handling
module Service
  class Illiad < Service::Base
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def build_service_url(_params, _bib_record, _current_user)
      return APP_CONFIG[:illiad_login_url]
    end
  end
end
