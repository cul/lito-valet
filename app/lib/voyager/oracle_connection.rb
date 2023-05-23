# Based on voyager-oracle-api

module Voyager
  # A Voyager::OracleConnection is the object which performs the query.
  #
  # It understands the Voyager table structures enough to build SQL for
  # extracting Holdings Status information, uses OCI to run the SQL, and
  # gathers up the raw results to an internal datastructure.
  class OracleConnection
    # attr_reader :connection
    # attr_accessor :results

    def initialize(args = {})
      args.symbolize_keys!
      @connection = args[:connection]

      unless args.key?(:connection)
        ora_args = APP_CONFIG['oracle_connection_details']

        raise "Need argument 'user'" unless ora_args.key?(:user)
        raise "Need argument 'password'" unless ora_args.key?(:password)
        raise "Need argument 'service'" unless ora_args.key?(:service)

        Rails.logger.debug "- opening Oracle connection #{ora_args.except('password')}"

        @connection = OCI8.new(ora_args[:user], ora_args[:password], ora_args[:service])
        # @connection.prefetch_rows = 1000
      end

      @results = {}
    end
    
    def get_patron_record(uni)
      Rails.logger.debug "- get_patron_record(uni=#{uni})"
      return nil unless uni.present?
      
      # If we've already fetched the patron record, return it
      return @patron_record if @patron_record.present?

      query = <<-HERE
        select institution_id, patron_id, expire_date, total_fees_due
        from   patron
        where  institution_id = ~uni~
      HERE

      full_query = fill_in_query_placeholders(query, uni: uni)
      raw_results = execute_select_command(full_query)
      if raw_results.size.zero?
        Rails.logger.warn "  no patron_id found in patron table for uni #{uni}!"
        return nil
      end
      @patron_record = raw_results.first
      return @patron_record
    end
    
    def get_patron_id(uni)
      Rails.logger.debug "- get_patron_id(uni=#{uni})"
      return nil unless uni.present?

      @patron_record ||= get_patron_record(uni)
      return nil unless @patron_record.present?

      patron_id = @patron_record['PATRON_ID']
      Rails.logger.debug "  found patron_id [#{patron_id}]"
      patron_id
    end

    # --- never called ---
    # def get_patron_barcode_record(patron_id)
    #   Rails.logger.debug "- get_patron_barcode_record(patron_id=#{patron_id})"
    #   return nil unless patron_id.present?
    #
    #   # If we've already fetched the patron record, return it
    #   return @patron_barcode_record if @patron_barcode_record.present?
    #
    #   query = <<-HERE
    #       select patron_barcode,
    #              patron_group_code,
    #              barcode_status
    #       from   patron_barcode,
    #              patron_group
    #       where  patron_id = ~patron_id~
    #       and    barcode_status = '1'
    #       and    patron_barcode.patron_group_id = patron_group.patron_group_id
    #   HERE
    #
    #   full_query = fill_in_query_placeholders(query, patron_id: patron_id)
    #   raw_results = execute_select_command(full_query)
    #   if raw_results.size.zero?
    #     Rails.logger.warn "  no record found in patron_barcode table for patron_id #{patron_id}!"
    #     return nil
    #   end
    #   @patron_barcode_record = raw_results.first
    #   return @patron_barcode_record
    # end

    # def retrieve_patron_expire_date(uni)
    #   Rails.logger.debug "- retrieve_patron_expire_date(uni=#{uni})"
    #   return nil unless uni.present?
    # 
    #   @patron_record ||= get_patron_record(uni)
    #   return nil unless @patron_record.present?
    # 
    #   expire_date = @patron_record['EXPIRE_DATE']
    #   Rails.logger.debug "  found expire_date [#{expire_date}]"
    #   expire_date
    # end

    # def retrieve_patron_total_fees_due(uni)
    #   return nil unless uni.present?
    # 
    #   @patron_record ||= get_patron_record(uni)
    #   return nil unless @patron_record.present?
    # 
    #   total_fees_due = @patron_record['TOTAL_FEES_DUE']
    #   Rails.logger.debug "  found total_fees_due [#{total_fees_due}]"
    #   total_fees_due
    # end

    # --- never called ---
    # def get_over_recall_notice_count(patron_id)
    #   return nil unless patron_id.present?
    #
    #   query = <<-HERE
    #       select   over_recall_notice_count
    #       from     columbiadb.circ_transactions
    #       where    patron_id = ~patron_id~
    #       and      over_recall_notice_count > 0
    #   HERE
    #
    #   full_query = fill_in_query_placeholders(query, patron_id: patron_id)
    #   raw_results = execute_select_command(full_query)
    #   return 0 if raw_results.size.zero?
    #
    #   @circ_transactions_record = raw_results.first
    #   return @circ_transactions_record['OVER_RECALL_NOTICE_COUNT']
    # end


    def retrieve_patron_email(patron_id)
      Rails.logger.debug "- retrieve_patron_email(patron_id=#{patron_id})"
      return nil unless patron_id.present?

      query = <<-HERE
        select address_line1
        from   patron_address
        where  patron_id = ~patron_id~
        and    address_type = 3
        and (expire_date > sysdate OR expire_date is null)
      HERE

      full_query = fill_in_query_placeholders(query, patron_id: patron_id)
      raw_results = execute_select_command(full_query)
      if raw_results.size.zero?
        Rails.logger.warn "  no patron_email found in patron_address table for patron_id #{patron_id}!"
        return nil
      end
      patron_email = raw_results.first['ADDRESS_LINE1']

      Rails.logger.debug "  found patron_email [#{patron_email}]"
      patron_email
    end

    # based on:
    #  https://www1.columbia.edu/sec-cgi-bin/cul/bd/BDauth
    def retrieve_patron_barcode(patron_id)
      Rails.logger.debug "- retrieve_patron_barcode(patron_id=#{patron_id})"
      return nil unless patron_id.present?

      query = <<-HERE
        select patron_id, 
               patron_barcode,
               patron_group_id,
               barcode_status
        from   columbiadb.patron_barcode
        where  patron_id = ~patron_id~
        and    barcode_status = '1'
      HERE

      full_query = fill_in_query_placeholders(query, patron_id: patron_id)
      raw_results = execute_select_command(full_query)
      if raw_results.size.zero?
        Rails.logger.warn "  no patron_barcode found in patron_barcode table for patron_id #{patron_id}!"
        return nil
      end
      patron_barcode = raw_results.first['PATRON_BARCODE']

      Rails.logger.debug "  found patron_barcode [#{patron_barcode}]"
      patron_barcode
    end

    # --- never called ---
    # def get_patron_stats(patron_id = nil)
    #   return [] unless patron_id
    #
    #   query = <<-HERE
    #     select   patron_stat_code
    #     from     patron_stat_code,
    #              patron_stats
    #     where    patron_stat_code.patron_stat_id = patron_stats.patron_stat_id
    #     and      patron_stats.patron_id = ~patron_id~
    #   HERE
    #
    #   full_query = fill_in_query_placeholders(query, patron_id: patron_id)
    #   raw_results = execute_select_command(full_query)
    #   return [] if raw_results.size.zero?
    #   raw_results.map { |row| row['PATRON_STAT_CODE'] }
    # end
    #
    # We don't need this method in Offsite Request processing
    #
    # def retrieve_holdings(*bibids)
    #   # to support connection re-use, reset to empty upon every new request
    #   @results['retrieve_holdings'] = {}
    #
    #   bibids = Array.wrap(bibids).flatten
    #
    #   query = <<-HERE
    #     select a.bib_id, a.mfhd_id, c.item_id, item_status
    #     from bib_mfhd a, mfhd_master b, mfhd_item c, item_status d
    #     where a.bib_id IN (~bibid~) and
    #     b.mfhd_id = a.mfhd_id and
    #     suppress_in_opac = 'N' and
    #     c.mfhd_id (+) = b.mfhd_id and
    #     d.item_id (+) = c.item_id
    #     order by c.mfhd_id, c.item_id, item_status
    #   HERE
    #
    #   if bibids.empty?
    #     return @results['retrieve_holdings'] ||= {}
    #   end
    #
    #   raw_results = []
    #
    #   # 10/2013
    #   # Sometimes our OCI connection times out in the midst of fetching
    #   # results.  There seems to be no way, in any language environment,
    #   # of setting a client-side timeout on OCI statement executions,
    #   # so wrap the whole connection in a Ruby-level timeout, and hope
    #   # there's no interference in signal-handling with the OCI libs.
    #   #
    #   # 11/2013
    #   # The OCI library does do it's own signal handling, including ignoring
    #   # alarms, so our hanging connections continue.  But this timeout does
    #   # fire when the Oracle server is slow, e.g., during rman backups,
    #   # causing immediate null results instead of very slow results.
    #   begin
    #     Timeout.timeout(10) do
    #       full_query = fill_in_query_placeholders(query, bibid: bibids)
    #       raw_results = execute_select_command(full_query)
    #     end
    #   rescue Timeout::Error => e
    #     # Try to cleanup the interrupted OCI connection
    #     @connection.break()
    #     raise "Timeout in execute_select_command()"
    #   end
    #
    #   parse_results(raw_results, name: 'retrieve_holdings', hash_by: 'BIB_ID')
    # end

    private

    def parse_results(results, *args)
      options = args.extract_options!
      @results[options[:name]] ||= {}
      result_hash = @results[options[:name]]

      results.each do |row|
        next unless (key = row[options[:hash_by]].to_s)
        if options[:single_result]
          result_hash[key] = row[options[:single_result]]
        else
          result_hash[key] ||= []
          result_hash[key] << row
        end
      end

      result_hash
    end

    def execute_select_command(query)
      cursor = @connection.parse(query)

      results = []
      cursor.exec

      cursor.fetch_hash do |row|
        results << row
      end

      cursor.close

      results
    end

    # Aren't there libraries that would do this for us?
    def fill_in_query_placeholders(query, *args)
      options = args.extract_options!
      options.each do |name, value|
        formatted_value = Array(value).collect do |item|
          "'#{item.to_s.gsub("'", "''")}'"
        end.join(',')
        query.gsub!("~#{name}~", formatted_value)
      end
      query
    end
  end
end
