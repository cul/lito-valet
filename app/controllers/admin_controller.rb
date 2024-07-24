class AdminController < ApplicationController
  before_action :authenticate_user!

  layout 'admin'

  def system
    return redirect_to root_path unless current_user.admin?
  end

  def request_services
    # Allow all CUL staff to view the configuration rules for Valet request services
    redirect_to root_path unless current_user && current_user.culstaff?

    # Don't hard-code a list of services here, discover them by looking through APP_CONFIG
    @request_service_list = Array.new
    APP_CONFIG.keys.each do |key_name|
      # no true scotsman
      next unless APP_CONFIG[key_name].is_a? Hash
      next unless APP_CONFIG[key_name].has_key?('label') && APP_CONFIG[key_name].has_key?('authenticate')

      @request_service_list.push key_name
    end
  end


  def logs
    return redirect_to root_path unless current_user.valet_admin?

    @log_dir = APP_CONFIG['log_directory']
    # sort newest first
    @log_files = Dir["#{@log_dir}/*.log"].sort.reverse

    # # download a specific log file
    # if log_file = params[:log_file]
    #   return redirect_to root_path unless @log_files.include?(log_file)
    #   send_file(log_file)
    #   return
    # end
    #
  end

  def log_file
    return redirect_to root_path unless current_user.valet_admin?

    log_file = params[:log_file]
    return redirect_to root_path unless log_file

    # Validate the input arg
    @log_dir = APP_CONFIG['log_directory']
    @log_files = Dir["#{@log_dir}/*.log"]
    return redirect_to root_path unless @log_files.include?(log_file)

    @headers = []
    @rows = []
    File.foreach(log_file) do |line|
      row = []

      line.split('|').each do |field|
        # gather headers only when working on first row
        header = '' if @rows.size.zero?
        if (match = field.match(/(\w+)=(.*)/))
          # If this field is key=value
          header, value = match.captures
        else
          # else if this field is "value" (no key)
          header = ''
          value = field
        end

        # Some fields are uninteresting, and don't need to be displayed
        next if header == 'requestingInstitution'

        row.push(value)
        # gather headers only when working on first row
        @headers.push(header) if @rows.size.zero?
      end

      @rows.push(row)
    end
  end
end
