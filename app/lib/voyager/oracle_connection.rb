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

      unless args.has_key?(:connection)
        # app_config = File.join(File.dirname(__FILE__),
        #                                 "../../..",
        #                                 "config",
        #                                 "app_config.yml")
        # 
        # args = YAML.load_file(app_config)['oracle_connection_details'] if
        #         args == {} and File.exists?(app_config)
        ora_args = APP_CONFIG['oracle_connection_details'].symbolize_keys!

        raise "Need argument 'user'" unless ora_args.has_key?(:user)
        raise "Need argument 'password'" unless ora_args.has_key?(:password)
        raise "Need argument 'service'" unless ora_args.has_key?(:service)

        @connection = OCI8.new(ora_args[:user], ora_args[:password], ora_args[:service])
        # @connection.prefetch_rows = 1000
      end

      @results = {}
    end


    def retrieve_patron_id(uni)
      query = <<-HERE
        select institution_id, patron_id, expire_date, total_fees_due
        from   patron
        where  institution_id = ~uni~
      HERE

      full_query = fill_in_query_placeholders(query, uni: uni)
      raw_results = execute_select_command(full_query)

      return raw_results.first['PATRON_ID']

      # parse_results(raw_results, name: 'retrieve_patron_id',
      #               hash_by: 'INSTITUTION_ID')

    end


    # based on:
    #  https://www1.columbia.edu/sec-cgi-bin/cul/bd/BDauth
    def retrieve_patron_barcode(patron_id)

      query = <<-HERE
        select patron_id, patron_barcode, patron_group_id, barcode_status
        from   columbiadb.patron_barcode
        where  patron_id = ~patron_id~
        and    barcode_status = '1'
        and    patron_group_id in ('2','4','3','14','15')
      HERE

      full_query = fill_in_query_placeholders(query, patron_id: patron_id)
      raw_results = execute_select_command(full_query)

      return raw_results.first['PATRON_BARCODE']

      # parse_results(raw_results, name: 'retrieve_patron_barcode', hash_by: 'PATRON_ID')
    end


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

        if (key = row[options[:hash_by]].to_s)
          if options[:single_result]
            result_hash[key] = row[options[:single_result]]
          else
            result_hash[key] ||= []
            result_hash[key] << row
          end
        end
      end

      return result_hash
    end


    def execute_select_command(query)
      cursor = @connection.parse(query)

      results = []
      cursor.exec

      cursor.fetch_hash do |row|
        results << row
      end

      cursor.close

      return results
    end

    # Aren't there libraries that would do this for us?
    def fill_in_query_placeholders(query, *args)
      options = args.extract_options!
      options.each do |name, value|
        formatted_value = Array(value).collect { |item|
          "'#{item.to_s.gsub("'", "''")}'"
        }.join(',')
        query.gsub!("~#{name.to_s}~", formatted_value)
      end
      return query
    end

  end
end
