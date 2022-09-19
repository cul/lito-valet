module ValetRequestsHelper
  # shortcuts used in several methods
  WWW  = 'http://www.columbia.edu'.freeze
  CGI  = 'http://www.columbia.edu/cgi-bin'.freeze
  LWEB = 'http://library.columbia.edu'.freeze

  def toc_link(clio_record = nil, barcode = nil)
    return '' unless clio_record.present? &&
                     clio_record.tocs.present? &&
                     barcode.present? &&
                     clio_record.tocs[barcode]
    label = 'Table of Contents'
    url = clio_record.tocs[barcode]
    link_to label, url, target: '_blank'
  end

  def my_library_account_link
    label = 'My Borrowing Account'
    url   = "#{CGI}/cul/resolve?lweb0087"
    link_to label, url, target: '_blank'
  end

  def borrowing_info_link
    label = 'More Information'
    url   = "#{LWEB}/services/borrowing.html"
    link_to label, url, target: '_blank'
  end

  def to_library_info_link
    label = 'more info...'
    url = "#{LWEB}/find/request/off-site.html"
    link_to label, url, target: '_blank', class: 'info-link'
  end

  def electronic_info_link
    label = 'more info...'
    url = "#{LWEB}/find/request/off-site.html"
    link_to label, url, target: '_blank', class: 'info-link'
  end

  # For a given offsite location code ('OFF AVE', 'OFF BIO'),
  # (or a customer code, e.g., 'QK', 'FL')
  # return the default on-campus delivery location ('AR', 'CA')
  def get_delivery_default(code)
    delivery_config = get_delivery_config(code)
    # Each location should have it's own default oncampus delivery
    # location defined.  But if it doesn't, fallback to Butler.
    delivery_config['default'] || 'bu'
  end

  # For a given offsite location code ('OFF AVE', 'OFF BIO'),
  # (or a customer code, e.g., 'QK')
  # return an array of available on-campus delivery locations.
  #   (by code, e.g., ['AR'] or ['AR', 'BL','UT'])
  def get_delivery_options(code)
    delivery_config = get_delivery_config(code)

    # If this config has an 'available' list defined,
    # return it.
    # Otherwise, just return the default list.
    delivery_config['available'] ||
      DELIVERY['standard_delivery_locations']
  end

  # code may be a location code or a customer code
  def get_delivery_config(code)
    delivery_config = DELIVERY[code]

    # If there are no specific delivery rules defined for
    # this offsite location, treat it as if it were 'OFF GLX'
    delivery_config = DELIVERY['off,glx'] if delivery_config.blank?

    delivery_config
  end

  # offsite_location_code is the location code of the holding
  # customer_code, if present, is a single string.
  # We're assuming a single customer code for all items within a holding.
  def delivery_select_tag(offsite_location_code, customer_code)
    delivery_options = nil
    delivery_default = nil

    if customer_code.present?
      delivery_options = get_delivery_options(customer_code)
      delivery_default = get_delivery_default(customer_code)
    end

    # If the customer-code logic didn't set these, lookup by location code
    delivery_options ||= get_delivery_options(offsite_location_code)
    delivery_default ||= get_delivery_default(offsite_location_code)

    # LIBSYS-3154 - OVERRIDE DELIVERY MENU
    # # - hardcode for first phase
    # delivery_options = [ 'BU' ]
    # delivery_default = 'BU'
    # second-phase, support a dynamic list
    active_delivery_locations = APP_CONFIG[:recap_loan][:active_delivery_locations]
    if active_delivery_locations
      # First - remove any location options that are not in the "active" list
      delivery_options = delivery_options.select { |location|
        active_delivery_locations.include?(location)
      }
      # Did we delete the last location?  Use 'BU' as last-resort fallback.
      delivery_options = [ 'BU' ] if delivery_options.empty?
      # Next, hardcode default, unless the default is an active location
      delivery_default = 'BU' unless active_delivery_locations.include?(delivery_default)
    end

    options_array = delivery_options.map do |delivery_location_code|
      [LOCATIONS[delivery_location_code], delivery_location_code]
    end

    select_tag(:deliveryLocation, options_for_select(options_array, delivery_default), class: 'retrieval-field')
  end

  def location_label(location_code_or_holding)
    return '' unless location_code_or_holding
    location_code = ''
    location_name = ''

    # old logic, brought over from CGIs, uses hardcoded table
    if location_code_or_holding.is_a? String
      location_code = location_code_or_holding
      location_name = LOCATIONS[location_code] || 'Offsite'
      # location_code = location_code_or_holding
    end
    # new logic, pull location name and code out of the holding
    if location_code_or_holding.is_a? Hash
      holding = location_code_or_holding
      location_code = holding[:location_code]
      location_name = holding[:location_display] || 'Offsite'
      # return "#{location_name} (#{location_code})"
    end

    # CLEANUP location name - similar to CLIO cleanup rules
    # from = 'delivery within 2 business days'
    # to   = 'electronic delivery'
    from = ' within 2 business days'
    to   = ''
    location_name.gsub!(/#{from}/, to)
    from = 'Place Request for delivery'
    to   = ''
    location_name.gsub!(/#{from}/, to)

    return "#{location_name} (#{location_code.upcase})"
  end

  def holding_radio_button_label(holding)
    mfhd_id = holding[:mfhd_id]
    radio_button_id = "mfhd_id_#{mfhd_id}"
    label = 'Call number ' + holding[:display_call_number] +
            ', location ' + location_label(holding[:location_code])

    label_tag(radio_button_id, label)
  end

  def use_restriction_note(holding, item)
    return '' unless holding.present? &&
                     item.present?

    # UT Missionary Research Library is very special,
    # they get their very own message.
    nonCircLocations = ['off,utmrl']
    if nonCircLocations.include?(holding[:location_code])
      return 'In library use only.'
    end

    return '' if item[:use_restriction].blank?

    # Return special language for fragile material.
    if item[:use_restriction].casecmp('FRGL').zero?
      return 'In library use only. "Item to Library" delivery only.'
    end

    # We need to show Use Restrictions from partners.
    # But Columbia uses staff-only codes ("TIED", "ENVE") which we don't
    # want to show to patrons.

    # Explicitly suppress Columbia codes, but show any other note verbatim
    return '' if %w(TIED ENVE).include?(item[:use_restriction])

    item[:use_restriction]
  end

  # There's a bit of complexity in the offsite request item checkboxes.
  # The barcode filter is for when the request is for a precise barcode,
  # for example, requesting the container item of a bound-with relationship.
  def request_item_check_box_tag(item, barcode_filter = nil)
    return '' unless item.present?
    # if we have a barcode filter, skip anything that doesn't match the filter
    return '' if barcode_filter.present? && item[:barcode] != barcode_filter

    # Normally unchecked, unless this item matches the barcode filter
    checked_state = false
    checked_state = true if item[:barcode] == barcode_filter

    # Setup data attributes
    options = item_data_hash(item)
    
    # mark all item checkboxes with a single class
    options[:class] = 'item_check_box'

    # Checkbox state immutable if barcode filter is active
    options[:onclick] = 'return false;' if barcode_filter.present?
    
    check_box_tag('itemBarcodes[]', item[:barcode], checked_state, options)
  end

  # Include extra attributes with the item barcode checkboxes via html data attribute
  def item_data_hash(item)
    datahash = {}

    # We want to know if an item is fragile - to disallow EDD
    if item[:use_restriction]
      datahash[:use_restriction] = item[:use_restriction].upcase
    end

    # If we found any data elements, return a data hash
    return { data: datahash } unless datahash.empty?

    # Otherwise, return nothing
    {}
  end

  def in_process_holdings_label(holding)
    location    = holding[:location_display]
    call_number = holding[:display_call_number]
    acq_info    = holding[:acquisitions_information].join(', ')
    data = [ location, call_number, acq_info ]
    return data.compact_blank.join(' - ')
  end

end
