# We use the library-number-normalization througout
require 'library_stdnums'

# now fixed.
# # UNIX-5942 - work around spotty CUIT DNS
# require 'resolv-hosts-dynamic'
# require 'resolv-replace'

class ApplicationController < ActionController::Base
  # Set headers to prevent all caching in authenticated sessions,
  # so that people can't 'back' in the browser to see possibly secret stuff.
  before_action :set_cache_headers

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, prepend: true

  include Devise::Controllers::Helpers
  devise_group :user, contains: [:user]

  # Referrer might be the CAS server, or might be valet for multi-form services.
  # Try to capture original non-valet referror for logging purposes.
  prepend_before_action :set_original_referrer

  # prepend_before_action :cache_dns_lookups

  # Services can store lengthy error message text here
  # for display on the error page
  attr_accessor :error

  # Register custom flash types
  add_flash_types :error

  # Overwriting the sign_out redirect path method
  def after_sign_out_path_for(_resource_or_scope)
    cas_opts = YAML.load_file(File.join(Rails.root, 'config', 'cas.yml'))[Rails.env] || {}

    # If CAS options are absent, we can only do application-level logout,
    # not CAS logout.  Warn, and proceed.
    unless cas_opts['host'] && cas_opts['logout_url']
      Rails.logger.error 'CAS options missing - skipping CAS logout!'
      return welcome_logout_path
    end

    # Full CAS logout + application logout page looks like this:
    # https://cas.columbia.edu/cas/logout?service=https://helpdesk.cul.columbia.edu/welcome/logout
    cas_logout_url = 'https://' + cas_opts['host'] + cas_opts['logout_url']
    service = request.base_url + welcome_logout_path
    after_sign_out_path = "#{cas_logout_url}?service=#{service}"
    Rails.logger.debug "after_sign_out_path = #{after_sign_out_path}"
    after_sign_out_path
  end

  # Return a hash with a set of attributes
  # of the current request, to be added to
  # a given log entry.
  # What do we want to know?
  # Referrer, Timestamp, IP,
  def request_data
    data = {}
    # Also for convenience store name and version
    data[:browser_name] = browser.name
    data[:browser_version] = browser.version
    data[:referrer]   = session[:referrer]
    data[:remote_ip]  = request.remote_ip
    data[:user_agent] = request.user_agent
    data
  end

  # LIBSYS-4432 - Deprecation of IDMACCESS_ADTO affiliation
  # # CUMC staff who have not completed security training
  # # may not use authenticated online request services.
  # def cumc_block
  #   return unless current_user && current_user.affils
  #   return error('Internal error - CUMC Block config missing') unless APP_CONFIG[:cumc]
  #   if current_user.has_affil(APP_CONFIG[:cumc][:block_affil])
  #     Rails.logger.info "CUMC block: #{current_user.login}"
  #     return redirect_to APP_CONFIG[:cumc][:block_url]
  #   end
  # end

  # apparently now fixed.
  # # UNIX-5942 - work around spotty CUIT DNS
  # def cache_dns_lookups
  #   dns_cache = []
  #   hostnames = [ 'ldap.columbia.edu', 'cas.columbia.edu' ]
  #   hostnames.each { |hostname|
  #     addr = getaddress_retry(hostname)
  #     dns_cache << { 'hostname' => hostname, 'addr' => addr } if addr.present?
  #   }
  #   return unless dns_cache.size > 0
  #
  #   Rails.logger.debug "cache_dns_lookups() dns_cache=#{dns_cache}"
  #
  #   cached_resolver = Resolv::Hosts::Dynamic.new(dns_cache)
  #   Resolv::DefaultResolver.replace_resolvers( [cached_resolver, Resolv::DNS.new] )
  # end
  #
  # def getaddress_retry(hostname = nil)
  #   return unless hostname.present?
  #
  #   addr = nil
  #   (1..3).each do |try|
  #     begin
  #       addr = Resolv.getaddress(hostname)
  #       break if addr.present?
  #     rescue => ex
  #       # failed?  log, pause, and try again
  #       Rails.logger.error "Resolv.getaddress(#{hostname}) failed on try #{try}: #{ex.message}, retrying..."
  #       sleep 1
  #     end
  #   end
  #
  #   return addr
  # end

  # Many of our services may want to use a common error page,
  # and may want flash errors and/or inset-box errors.

  # Let caller just do:
  #    if broken() return error("Broken!")
  # instead of multi-line if/end
  def error(message)
    flash.now[:error] = message
    # service_error = begin
    #                   self.error
    #                 rescue
    #                   ''
    #                 end
    render '/forms/error', locals: { service_error: @error || '' }
  end

  private

  def set_cache_headers
    if current_user
      response.headers['Cache-Control'] = 'no-cache, no-store'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
    end
  end

  # save original non-valet, non-cas referrer
  def set_original_referrer
    # blank referrer
    return if request.referrer.blank?
    # self-referrer (multi-form valet service)
    return if URI(request.referrer).host == request.host
    # referrer set to authentication host
    return if URI(request.referrer).host == 'cas.columbia.edu'

    # ok - looks like an external original referrer that we care about
    session[:referrer] = request.referrer
  end
end
