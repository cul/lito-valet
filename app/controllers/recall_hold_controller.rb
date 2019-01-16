class RecallHoldController < ApplicationController

  # Voyager doesn't respect our CAS SSO.
  # To avoid double-authentication, we'll redirect & log anonymously,
  # so skip the "before_action :authenticate_user!"

  # CUMC staff who have not completed security training
  # may not use authenticated online request services.
  before_action :cumc_block
  
  def show
    @config = APP_CONFIG['recall_hold']

    # validate user
    # Do we want to do any user validation?
    # No - bounce any visitor over to Voyager's authentication.

    # validate requested bib
    bib_record = ClioRecord.new_from_bib_id(params['id'])
    return error("No bib record found for id = #{params['id']}") if bib_record.nil?
    return error("Bib record #{params['id']} not owned by Columbia") unless bib_record.voyager?
      
    # log
    log_recall_hold(params, bib_record, current_user)
    
    # bounce patron to Voyager
    redirect_url = APP_CONFIG[:recall_hold][:voyager_url] + bib_record.id
    return redirect_to redirect_url
  end


  # If we want more verbose error messages we can do something like this:
  # def valid_bib?(bib_record)
  #   # Any record in Voyager is ok
  #   return true if bib_record && bib_record.voyager?
  # 
  #   # Anything else (ReCAP partner records, Law records, etc.) cannot be requested
  #   self.error = 'This catalog record is not owned by Columbia.<br><br>Recall / Hold services are only available for Columbia material.'
  #   return false
  # end


  def log_recall_hold(params, bib_record, current_user)
    data = { set: @config[:label] || 'Recall / Hold'}
    
    # basic request data - ip, timestamp, etc.
    data.merge! request_data

    # the 'logdata' key is service-specific data.
    # - tell about the user
    logdata =  {user: current_user.present? ? current_user.login : ''}
    # - tell about the bib
    logdata.merge! bib_record.basic_log_data
    # logdata is stored as in JSON
    data[:logdata] = logdata.to_json

    begin
      # If logging fails, don't die - report the error and continue
      Log.create(data)
    rescue => ex
      Rails.logger.error "RecallHoldController#log error: #{ex.message}"
      Rails.logger.error data.inspect
    end
    
  end

end
