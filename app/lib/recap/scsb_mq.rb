module Recap
  class ScsbMq
    attr_reader :conn, :scsb_args

    def self.get_scsb_mq_args
      app_config_key = 'mq_connection_details'
      scsb_args = APP_CONFIG['scsb'][app_config_key]
      raise "Cannot find #{app_config_key} in APP_CONFIG!" if scsb_args.blank?

      [:host, :port].each do |key|
        raise "SCSB config needs value for '#{key}'" unless scsb_args.key?(key)
      end

      @scsb_args = scsb_args
    end

    def self.stomp_config
      config = {
        hosts:                    [
          { login: '', passcode: '',
            host: @scsb_args[:host], port: @scsb_args[:port],
            ssl: true }
        ],
        # These are the default parameters and do not need to be set
        reliable:                 true, # reliable (use failover)
        initial_reconnect_delay:  0.01, # initial delay before reconnect (secs)
        max_reconnect_delay:      30.0, # max delay before reconnect
        use_exponential_back_off: true, # increase delay between reconnect attpempts
        back_off_multiplier:      2, # next delay multiplier
        max_reconnect_attempts:   0, # retry forever, use # for maximum attempts
        randomize:                false, # do not radomize hosts hash before reconnect
        connect_timeout:          0,              # Timeout for TCP/TLS connects, use # for max seconds
        connect_headers:          {},             # user supplied CONNECT headers (req'd for Stomp 1.1+)
        parse_timeout:            5, # IO::select wait time on socket reads
        logger:                   nil, # user suplied callback logger instance
        dmh:                      false, # do not support multihomed IPV4 / IPV6 hosts during failover
        closed_check:             true, # check first if closed in each protocol method
        hbser:                    false, # raise on heartbeat send exception
        stompconn:                false, # Use STOMP instead of CONNECT
        usecrlf:                  false, # Use CRLF command and header line ends (1.2+)
        max_hbread_fails:         0,             # Max HB read fails before retry.  0 => never retry
        max_hbrlck_fails:         0,             # Max HB read lock obtain fails before retry.  0 => never retry
        fast_hbs_adjust:          0.0, # Fast heartbeat senders sleep adjustment, seconds, needed ...
        # For fast heartbeat senders.  'fast' == YMMV.  If not
        # correct for your environment, expect unnecessary fail overs
        connread_timeout:         0, # Timeout during CONNECT for read of CONNECTED/ERROR, secs
        tcp_nodelay:              true, # Turns on the TCP_NODELAY socket option; disables Nagle's algorithm
        start_timeout:            0, # Timeout around Stomp::Client initialization
        sslctx_newparm:           nil, # Param for SSLContext.new
        ssl_post_conn_check:      true, # Further verify broker identity
      }

      # Anything we want to amend?
      # config.merge {}

      config
    end

    def self.open_connection
      return @conn if @conn

      get_scsb_mq_args
      url ||= @scsb_args[:url]
      Rails.logger.debug "- opening new STOMP connection to #{url}"
      @conn = Faraday.new(url: url)
      raise "Faraday.new(#{url}) failed!" unless @conn

      @conn.headers['Content-Type'] = 'application/json'
      @conn.headers['api_key'] = @scsb_args[:api_key]

      @conn
    end
  end
end
