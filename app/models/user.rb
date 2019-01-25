class User < ApplicationRecord
  include Cul::Omniauth::Users

  require 'resolv'

  # cul_omniauth includes several options (:registerable,
  # :recoverable, :rememberable, :trackable, :validatable, ...)
  # but we also want...
  devise :timeoutable

  serialize :affils, Array

  attr_reader :ldap_attributes, :patron_id, :oracle_connection

  # cul_omniauth sets "devise :recoverable", and that requires
  # that the following user attributes be available.
  attr_accessor :reset_password_token, :reset_password_sent_at

  # Before first-time User record creation...
  before_create :set_personal_info_via_ldap, :set_email

  # Every user-object instantiation...
  after_initialize :set_personal_info_via_ldap
  after_initialize :set_email
  after_initialize :set_barcode_via_oracle

  # we don't need this
  # after_initialize :get_scsb_patron_information

  def to_s
    if first_name
      first_name.to_s + ' ' + last_name.to_s
    else
      login
    end
  end

  def name
    to_s
  end

  def set_personal_info_via_ldap
    # return if we already fetched ldap attributes
    return unless @ldap_attributes.nil?

    # Can't proceed without a uid!
    return unless uid

    ldap_args = APP_CONFIG['ldap_connection_details']
    raise "LDAP config needs 'host'" unless ldap_args.key?(:host)
    raise "LDAP config needs 'port'" unless ldap_args.key?(:port)
    raise "LDAP config needs 'base'" unless ldap_args.key?(:base)
    
    # This should use Resolv-Replace instead of DNS
    ldap_ip_address = Resolv.getaddress(ldap_args[:host])

    # DNS retry logic moved to ApplicationController#cache_dns_lookups()
    #
    # # CUIT DNS sometimes fails (UNIX-5942).  Retry a few times.
    # ldap_ip_address = nil
    # 3.times do
    #   break if ldap_ip_address.present?
    #   begin
    #     ldap_ip_address = Resolv.getaddress(ldap_args[:host])
    #   rescue => ex
    #     # failed?  pause, and try again
    #     Rails.logger.error "Resolv.getaddress(#{ldap_args[:host]}) failed: #{ex.message}, retrying..."
    #     sleep 1
    #   end
    # end
    # 
    # if ldap_ip_address.blank?
    #   Rails.logger.error "Unable to resolve hostname #{ldap_args[:host]}!."
    #   return
    # end

    # Rails.logger.debug "Querying LDAP #{ldap_ip_address} #{ldap_args.inspect} for uid=#{uid}"
    # entry = Net::LDAP.new(host: ldap_ip_address, port: ldap_args[:port]).search(base: ldap_args[:base], filter: Net::LDAP::Filter.eq('uid', uid)) || []
    Rails.logger.debug "Querying LDAP #{ldap_args.inspect} for uid=#{uid}"
    # entry = Net::LDAP.new(host: ldap_args[:host], port: ldap_args[:port]).search(base: ldap_args[:base], filter: Net::LDAP::Filter.eq('uid', uid)) || []
    entry = Net::LDAP.new(host: ldap_ip_address, port: ldap_args[:port]).search(base: ldap_args[:base], filter: Net::LDAP::Filter.eq('uid', uid)) || []
    entry = entry.first
    Rails.logger.debug "LDAP response: #{entry.inspect}"

    if entry
      # Copy all attributes of the LDAP entry to an instance variable,
      # keeping them in list format
      @ldap_attributes = {}
      entry.each_attribute do |attribute, value_list|
        next if value_list.blank?
        @ldap_attributes[attribute] = value_list
      end

      # Process certain raw attributes into cleaned up fields
      self.last_name  = Array(entry[:sn]).first.to_s
      self.first_name = Array(entry[:givenname]).first.to_s
    end

    self
  end

  def set_email
    # Try to find email via LDAP
    if @ldap_attributes && (ldap_mail = @ldap_attributes[:mail])
      ldap_mail = Array(ldap_mail).first.to_s
      if ldap_mail.length > 6 && ldap_mail.match(/^.+@.+$/)
        self.email = ldap_mail
        return self
      end
    end

    # Try to find email via Voyager
    if @oracle_connection ||= Voyager::OracleConnection.new
      if @patron_id ||= @oracle_connection.get_patron_id(uid)
        if (voyager_email = @oracle_connection.retrieve_patron_email(@patron_id))
          if voyager_email.length > 6 && voyager_email.match(/^.+@.+$/)
            self.email = voyager_email
            return self
          end
        end
      end
    end

    # No email!  Fill in guess.
    Rails.logger.error "ERROR: Cannot find email address via LDAP or Voyager for uid [#{uid}], assuming @columbia.edu"
    self.email = "#{uid}@columbia.edu"
    self
  end

  def set_barcode_via_oracle
    self.barcode = ''

    if uid
      if @oracle_connection ||= Voyager::OracleConnection.new
        if @patron_id ||= @oracle_connection.get_patron_id(uid)
          if (patron_barcode = @oracle_connection.retrieve_patron_barcode(@patron_id))
            self.barcode = patron_barcode
          end
        end
      end
    end

    self.barcode
  end

  def login
    uid.split('@').first
  end

  def email
    email = super
    self.email = email
    email
  end

  # Password methods required by Devise.
  def password
    Devise.friendly_token[0, 20]
  end

  def password=(*val)
    # NOOP
  end

  def phone
    get_first_ldap_value('telephonenumber', 'campusphone')
  end

  def department
    get_first_ldap_value('ou')
  end

  def get_first_ldap_value(*attribute_list)
    # Try passed attributes in preference order
    Array(attribute_list).each do |attribute|
      value_list = @ldap_attributes[attribute]
      Array(value_list).each do |value|
        return value unless value.blank?
      end
    end
    # fallback, return an empty string value
    ''
  end

  def has_affil(affil = nil)
    return false if affil.blank?
    return false unless affils
    affils.include?(affil)
  end

  def offsite_eligible?
    return false unless affils

    # Offsite eligibility set via app_config
    config = APP_CONFIG['offsite'] || {}

    # But hardcode a default, in case nothing is set in app_config
    if config['permitted_affils'].blank? && config['permitted_affil_regex'].blank?
      config['permitted_affil_regex'] = ['CUL_role-clio']
    end

    eligible?(config, affils)
  end

  def offsite_blocked?
    return false unless affils
    # This is not a "denied" affiliation,
    # because blocked users can still request physical delivery.
    affils.each do |affil|
      return true if affil =~ /CUL_role-clio-.*-blocked/
    end
    false
  end

  def ill_eligible?
    return false unless affils

    # Default to allow users with any 'CUL_role-clio*' affil,
    # but override with the app_config setting, if present
    config = APP_CONFIG['offsite'] || {}

    eligible?(config, affils)
  end

  def eligible?(config, affils)
    unless config.present? && affils.present?
      Rails.logger.error 'elibible?(config,affils) needs valid input args'
      return false
    end

    denied_affils         = config['denied_affils']         || []
    permitted_affils      = config['permitted_affils']      || []
    permitted_affil_regex = config['permitted_affil_regex'] || []

    [denied_affils, permitted_affils, permitted_affil_regex].each do |f|
      raise "#{f} must be an array!" unless f.is_a? Array
    end

    unless permitted_affils.present? || permitted_affil_regex.present?
      Rails.log.error 'Cannot find ANY permitted_affils - no access allowed!'
      return false
    end

    # Immediate rejection
    denied_affils.each do |bad_affil|
      Rails.logger.debug "#{login} has bad_affil #{bad_affil}" if
          affils.include?(bad_affil)
      return false if affils.include?(bad_affil)
    end
    permitted_affils.each do |good_affil|
      Rails.logger.debug "#{login} has good_affil #{good_affil}" if
          affils.include?(good_affil)
      return true if affils.include?(good_affil)
    end
    permitted_affil_regex.each do |good_regex|
      affils.each do |affil|
        Rails.logger.debug "affil #{affil} matches regexp #{good_regex}" if
            affil =~ /#{good_regex}/
        return true if affil =~ /#{good_regex}/
      end
    end

    # Default, if not explicitly permitted, return elible == false
    false
  end

  # developers and sysadmins
  def admin?
    affils && (affils.include?('CUNIX_litosys') || affils.include?('CUL_dpts-dev'))
  end

  # application-level admin permissions
  def valet_admin?
    return true if admin?
    valet_admins = Array(APP_CONFIG['valet_admins']) || []
    return true if valet_admins.include? login
    # We don't have any more granular permissions!!
    return true if affils && affils.include?('CUL_allstaff')

    # default case - not an admin
    return false
  end


  
  # GETTERS / SETTERS
  
  def oracle_connection
    @oracle_connection ||= Voyager::OracleConnection.new
  end
  def oracle_connection=(val)
    @oracle_connection = val
  end
  
  def patron_record
    # Rails.logger.debug "GETTER patron_record"
    @patron_record ||= oracle_connection.get_patron_record(uid)
  end
  def patron_record=(val)
    # Rails.logger.debug "SETTER patron_record=(val)"
    @patron_record = val
  end
  
  def patron_id
    @patron_id ||= patron_record['PATRON_ID']
  end
  def patron_id=(val)
    @patron_id = val
  end

  def over_recall_notice_count
    @over_recall_notice_count ||= oracle_connection.get_over_recall_notice_count(patron_id)
  end
  def over_recall_notice_count=(val)
    @over_recall_notice_count = val
  end
  
  def patron_barcode_record
    @patron_barcode_record ||= oracle_connection.get_patron_barcode_record(patron_id)
  end
  def patron_barcode_record=(val)
    @patron_barcode_record = val
  end
      
  def patron_group
    patron_barcode_record['PATRON_GROUP_CODE']
  end
  def patron_group=(val)
    @patron_barcode_record['PATRON_GROUP_CODE'] = val
  end

  def patron_stats
    @patron_stats || oracle_connection.get_patron_stats(patron_id)
  end
  def patron_stats=(val)
    @patron_stats = val
  end

  

  # TESTS

  def patron_expired?
    expired = patron_record['EXPIRE_DATE'] < Time.now
    Rails.logger.info "patron expired! (#{uid})" if expired
    return expired
  end
  
  def patron_blocked?
    blocked = patron_record['TOTAL_FEES_DUE'] > 9999
    Rails.logger.info "patron blocked! (#{uid})" if blocked
    return blocked
  end
  
  def patron_has_recalls?
    recalls = over_recall_notice_count > 0
    Rails.logger.info "patron has recalls! (#{uid})" if recalls
    return recalls
  end
  
  def patron_2cul?
    is_2cul = patron_stats.include?('2CU')
    Rails.logger.info "patron is 2cul (#{uid})" if is_2cul
    return is_2cul
  end
  
end
