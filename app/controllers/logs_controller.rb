class LogsController < ApplicationController
  require 'csv'

  before_action :authenticate_user!

  layout 'admin'

  # /logs/set=XXX
  #  - earliest/latest info
  #  - for each year, record-count, download-link
  #      - for each month, record-count, download-link
  # ... and datatable, at what level?  Day or Month or Year?
  # ... determined by record-count at that level?  (if < N, link)

  def index
    return error('Log access restricted') unless current_user.valet_admin?
    
    @logset = log_params[:logset]

    # If no set of logs was specified,
    # ask for which one.
    if @logset.blank?
      @logset_counts = Log.group('logset').distinct.count
      return render action: 'logset_list'
    end

    # If they've asked for access to a set, 
    # make sure they're permitted

    # Have they asked to download a year of logs for a given logset?
    # download param may be a year (YYYY) or year/month (YYYY-MM).
    download = log_params[:download]
    if download.present?
      # @rows = Log.where(logset: @logset).by_year(download).order(:created_at)
      @rows = logs_by_date(download).order(created_at: :asc)

      # This set's keys, derived from the JSON logdata of an example row
      @logdata_keys = get_keys_from_logdata(@rows.last)
      # standard keys for any logged requests (ip, user-agent, etc.)
      @request_keys = request_keys

      filename = "#{@logset} #{download}".parameterize.underscore + '.csv'

      response.headers['Content-Type'] = 'text/csv'
      response.headers['Content-Disposition'] = "attachment; filename=#{filename}"
      return render template: 'logs/index.csv.erb'
    end

    @year_month = log_params[:year_month]

    # If they haven't told us which year/month to display,
    # ask them.
    if @year_month.blank?
      @year_counts = get_year_counts
      @month_counts = get_month_counts
      return render action: 'month_list'
    end

    # OK, we're going to move forward and display an interactive JS datatable
    # of a given year/month for a given logset.
    @rows = logs_by_date(@year_month).order(created_at: :desc)

    # This logset's keys, derived from the JSON logdata of an example row
    @logdata_keys = get_keys_from_logdata(@rows.first)

    # standard keys for any logged requests (ip, user-agent, etc.)
    @request_keys = request_keys
  end

  # # Bounce the user to a destination URL,
  # # while logging the event
  # def bounce
  #   url = log_params[:url]
  #   # can't redirect, go to root
  #   if url.blank?
  #     Rails.logger.error "LogsController#bounce() called w/out 'url' param"
  #     return redirect_to root_path, flash: { error: 'No destination URL given' }
  #   end
  #
  #   # can't log - redirect w/log record
  #   set = log_params[:set]
  #   if set.present?
  #     # logdata is a serial
  #     logdata = log_params[:logdata] || ''
  #     all_data = request_data.merge(set: set, logdata: logdata)
  #     begin
  #       # If the database save fails, log it, continue the redirect
  #       Log.create(all_data)
  #     rescue => ex
  #       Rails.logger.error "LogsController#bounce error: #{ex.message}"
  #       Rails.logger.error all_data.inspect
  #     end
  #   else
  #     Rails.logger.error "LogsController#bounce(#{url}) called w/out 'set' param"
  #   end
  #
  #   return redirect_to url
  # end

  # Display a list of available log sets
  # ('ILL', 'Scan & Deliver', etc.)
  def logsets
  end

  private

  def log_params
    params.permit(:logset, :logdata, :url, :year_month, :download, :format)
  end

  # return array of keys of the basic request fields
  def request_keys
    [:created_at, :user_agent, :browser_name, :browser_version, :referrer, :remote_ip]
  end

  # Figure out appropriate keys for this logset by looking
  # at the JSON logdata of the first retrieved row
  def get_keys_from_logdata(row)
    return [] if row.blank?
    begin
      logdata = JSON.parse(row['logdata'])
      return logdata.keys
    rescue
      Rails.logger.warn "JSON.parse() failed for row [#{row.inspect}]"
    end
    []
  end

  def get_year_counts
    # default clause works in MySQL
    group_clause = 'date_format(created_at, "%Y")'

    # SQLite needs something special
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      group_clause = 'strftime("%Y", created_at)'
    end

    counts = Log.where(logset: @logset).group(group_clause).count

    # return counts, sorted by hash key (year)
    return counts.sort.to_h
  end

  def get_month_counts
    # default clause works in MySQL
    group_clause = 'date_format(created_at, "%Y-%m")'

    # SQLite needs something special
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      group_clause = 'strftime("%Y-%m", created_at)'
    end

    counts = Log.where(logset: @logset).group(group_clause).count

    # return counts, sorted by hash key (year-month)
    return counts.sort.to_h
  end

  # download param may be a year (YYYY) or year/month (YYYY-MM).
  def logs_by_date(download = nil)
    return ActiveRecord::NullRelation unless download.present?
    return log_by_year(download) if download =~ /^\d\d\d\d$/
    return log_by_month(download) if download =~ /^\d\d\d\d\-\d\d$/
    # Any bad data, return null set
    ActiveRecord::NullRelation
  end

  def log_by_year(download)
    # default clause works in MySQL
    where_clause = "year(created_at) = '#{download}'"

    # SQLite needs something special
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      where_clause = "strftime('%Y', created_at) = '#{download}'"
    end

    Log.where(logset: @logset).where(where_clause)
  end

  def log_by_month(download)
    year, month = download.split(/-/)
    # default clause works in MySQL
    where_clause = "year(created_at) = '#{year}' AND month(created_at) = '#{month}'"

    # SQLite needs something special
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      where_clause = "strftime('%Y', created_at) = '#{year}' AND strftime('%m', created_at) = '#{month}'"
    end

    Log.where(logset: @logset).where(where_clause)
  end
end
