# Our CLIO Record class is primarily a MARC::Record container,
# with a few convenience methods specific to this application.
#
# It is not a Blacklight Document.
class ClioRecord
  attr_reader :marc_record, :holdings, :barcodes,
              :scsb_availability, :voyager_availability,
              # :available_item_count,
              :tocs, :owningInstitution

  def initialize(marc_record = nil)
    @marc_record = marc_record

    # TODO: - do this better
    populate_holdings
    populate_owningInstitution
    populate_barcodes
    fetch_tocs

    # self.fetch_locations
    # self.fetch_availabilty

    # instance variables to hold hash of per-item/per-barcode availability.
    @scsb_availability = nil
    @voyager_availability = nil
  end

  def self.new_from_bib_id(bib_id = nil)
    if bib_id.blank?
      Rails.logger.error 'ClioRecord::new_from_bib_id() missing bib_id!'
      return nil
    end
    query = { id: bib_id }
    new_from_query(query)
  end

  def self.new_from_barcode(barcode = nil)
    if barcode.blank?
      Rails.logger.error 'ClioRecord::new_from_barcode() missing barcode!'
      return nil
    end
    query = { barcode_txt: barcode }
    new_from_query(query)
  end

  def self.new_from_query(query = nil)
    if query.blank?
      Rails.logger.error 'ClioRecord::new_from_query() missing query!'
      return nil
    end

    solr_connection = Clio::SolrConnection.new
    raise 'Clio::SolrConnection failed!' unless solr_connection

    marcxml = solr_connection.retrieve_marcxml_by_query(query)
    if marcxml.blank?
      Rails.logger.error 'ClioRecord::new_from_bib_id() marcxml nil!'
      return nil
    end

    reader = MARC::XMLReader.new(StringIO.new(marcxml))
    marc_record = reader.entries[0]
    if marc_record.blank?
      Rails.logger.error 'ClioRecord::new_from_bib_id() marc_record nil!'
      return nil
    end

    ClioRecord.new(marc_record)
  end

  # Ruby MARC field access methods:
  #     record.fields("500")  # returns an array
  #     record.each_by_tag("500") {|field| ... }
  # You can iterate through the subfields in a Field:
  #   field.each {|s| print s}

  # Hash of basic bib fields, used in logging of most request services
  def basic_log_data
    {
      bib_id: id,
      title:  title,
      author: author
    }
  end

  def id
    @marc_record['001'].value
  end

  def owningInstitutionBibId
    case owningInstitution
    when 'CUL'
      return @marc_record['001'].value
    else
      return @marc_record['009'].value
    end
  end

  def folio?
    owningInstitution == 'CUL' && (id.match(/^\d+$/) || id.match(/^in/))
  end

  def title
    return '' unless @marc_record && @marc_record['245']

    subfieldA = @marc_record['245']['a'] || ''
    subfieldB = @marc_record['245']['b'] || ''
    title = subfieldA.strip
    title += " #{subfieldB.strip}" if subfieldB.present?
    # return the cleaned up title
    trim_punctuation(title)
  end

  # For some purposes (e.g., Borrow Direct) we want only 245$a (NEXT-1735)
  def title_brief
    return '' unless @marc_record && @marc_record['245']

    subfieldA = @marc_record['245']['a'] || ''
    title = subfieldA.strip
    # return the cleaned up title
    trim_punctuation(title)
  end

  def author
    author_tokens = []
    %w(100 110 111).each do |field|
      # skip ahead to the first author field we find
      next unless @marc_record[field].present?

      # gather up a few subfields
      'abcj'.split(//).each do |subfield|
        author_tokens << @marc_record[field][subfield]
      end
      # stop once the 1st possible field is found & processed
      break
    end
    # combine all subfields into a string
    author = author_tokens.compact.join(' ')
    # return the cleaned up string
    trim_punctuation(author)
  end

  # SCSB works with a "titleIdentifier", which is assumed
  # to have the MARCish title + author in a single string
  def titleIdentifier
    titleIdentifier = title + ' / ' + author
    titleIdentifier
  end

  def publisher
    publisher ||= []
    %w(260 264).each do |field|
      next unless @marc_record[field]

      'abcefg3'.split(//).each do |subfield|
        publisher << @marc_record[field][subfield]
      end
      # stop once the 1st possible field is found & processed
      break
    end
    publisher.compact.join(' ')
  end

  def pub_field
    pub_field = @marc_record['260'] || @marc_record['264'] || nil
    pub_field
  end

  def pub_place
    return '' unless (pub_field = self.pub_field)
    return '' unless (pub_place = pub_field['a'])

    pub_place.sub(/\s*[:;,]$/, '')
  end

  def pub_name
    return '' unless (pub_field = self.pub_field)
    return '' unless (pub_name = pub_field['b'])

    pub_name.sub(/\s*[:;,]$/, '')
  end

  def pub_date
    return '' unless (pub_field = self.pub_field)
    return '' unless (pub_date = pub_field['c'])

    pub_date.sub(/\s*[:;,]$/, '')
  end

  def edition
    edition ||= []
    'ab'.split(//).each do |subfield|
      edition << @marc_record['250'][subfield] if @marc_record['250']
    end
    edition.compact.join(' ')
  end

  def call_number
    # First try to get call number from the 992 (local field)
    tag992 = @marc_record['992']
    call_number_992 = call_number_from_992(tag992)
    return call_number_992 if call_number_992.present?

    # If that didn't work, try to get call number from the 050
    tag050 = @marc_record['050']
    call_number_050 = call_number_from_050(tag050)
    return call_number_050 if call_number_050.present?

    # none found?
    return nil
  end

  CALL_NUMBER_ONLY = /^.* \>\> (.*)\|DELIM\|.*/

  def call_number_from_992(tag992 = nil)
    return nil unless tag992 && tag992['b']

    # If the regexp finds a call-number, return it.
    if matchdata = tag992['b'].match(CALL_NUMBER_ONLY)
      return matchdata[1]
    else
      return nil
    end
  end

  def call_number_from_050(tag050 = nil)
    return '' unless tag050

    subfield_values = []
    tag050.each do |subfield|
      subfield_values.push subfield.value
    end
    call_number = subfield_values.join(' ') || ''
    call_number
  end

  def oclc_number
    # 035 - System Control Number, may be OCLC or something else
    @marc_record.fields('035').each do |field|
      next unless (number = field['a'])

      oclc_regex = /OCoLC[^0-9A-Za-z]*([0-9A-Za-z]*)/
      next unless (oclc_match = number.match(oclc_regex))

      oclc_number = oclc_match[1]
      return oclc_number
    end
    # didn't find any 035, or any 035 that looks like an OCLC number?
    return nil
  end

  # Bibs can have multiple ISBNs for different formats,
  # and 020$a can have ISBN together with notes "123 (paperback)"
  def isbn
    return nil unless @marc_record.fields('020')

    isbns = @marc_record.fields('020').map do |field|
      StdNum::ISBN.normalize(field['a'])
    end
    isbns.compact
  end

  def issn
    @marc_record.fields('022')
    issns = @marc_record.fields('022').map do |field|
      StdNum::ISSN.normalize(field['a'])
    end
    # StdNum module returns digits only.
    # Map to hyphenated form (NNNN-NNNN)
    issns.compact.map do |digits|
      digits[0..3] + '-' + digits[4..7]
    end
  end

  # Finding-Aid links look like:
  #   https://findingaids.library.columbia.edu/ead/nnc-rb/ldpd_4079355
  # Return the first found, or if none found, return nil
  def finding_aid_link
    @marc_record.fields('856').each do |field|
      url = field['u']
      # has to look like a finding aid...
      next unless url.match(/findingaids.library.columbia.edu/) or
                  url.match(/findingaids.cul.columbia.edu/)
      # cannot be a downloadable document...
      next if url.match(/(pdf|doc|htm|html)$/)

      return url
    end
    return nil
  end

  def populate_owningInstitution
    return 'CUL' unless holdings.present?

    case holdings.first[:location_code]
    when 'scsb-nypl', 'scsbnypl'
      @owningInstitution = 'NYPL'
    when 'scsb-pul', 'scsbpul'
      @owningInstitution = 'PUL'
    when 'scsbhl'
      @owningInstitution = 'HL'
    else
      @owningInstitution = 'CUL'
    end
  end

  # Drill down into the MARC fields to build an
  # array of holdings.  See:
  # https://wiki.library.columbia.edu/display/cliogroup/Holdings+Revision+project
  def populate_holdings
    mfhd_fields = {
      summary_holdings:         '866',
      supplements:              '867',
      indexes:                  '868',
      public_notes:             '890',
      donor_information:        '891',
      reproduction_note:        '892',
      url:                      '893',
      acquisitions_information: '894',
      current_issues:           '895'
    }

    # Process each 852, creating a new mfhd for each
    holdings = {}
    @marc_record.each_by_tag('852') do |tag852|
      mfhd_id = tag852['0']

      # Call Number might be defined at the Bib or Holdings level.
      # Holdings call number, if present, takes precedence.
      best_call_number = tag852['h'].present? ? tag852['h'] : self.call_number

      holdings[mfhd_id] = {
        mfhd_id:             mfhd_id,
        location_display:    tag852['a'],
        location_code:       tag852['b'],
        display_call_number: best_call_number,
        items:               []
      }
      # And fill in all possible mfhd fields with empty array
      mfhd_fields.each_pair do |label, _tag|
        holdings[mfhd_id][label] = []
      end
    end

    # Scan the MARC record for each of the possible mfhd fields,
    # if any found, add to appropriate Holding
    # (e.g., label :summary_holdings, tag '866')
    mfhd_fields.each_pair do |label, tag|
      @marc_record.each_by_tag(tag) do |mfhd_data_field|
        mfhd_id = mfhd_data_field['0']
        value = mfhd_data_field['a']
        next unless mfhd_id && holdings[mfhd_id] && value

        holdings[mfhd_id][label] << value
      end
    end

    # Now add the list of items to each holding.
    @marc_record.each_by_tag('876') do |item_field|
      # build the Item hash
      item = {
        item_id:            item_field['a'],
        use_restriction:    item_field['h'],
        temporary_location: item_field['l'],
        barcode:            item_field['p'],
        blind_barcode:      item_field['x'],
        enum_chron:         item_field['3']
        # customer_code:      item_field['z']
      }
      # Store this item hash in the apppropriate Holding
      mfhd_id = item_field['0']

      # should not happen - but just in case...
      next unless holdings.key?(mfhd_id)

      holdings[mfhd_id][:items] << item
      # Assume a single customer code per holding.
      if item_field['z'].present?
        holdings[mfhd_id][:customer_code] = item_field['z']
      end
    end

    # Now that all the data is matched up, we don't need
    # the hash of mfhd_id ==> holdings_hash
    # Just store an array of Holdings
    @holdings = holdings.values
  end

  def offsite_holdings
    holdings.select do |holding|
      is_offsite_location_code?(holding[:location_code])
      # LOCATIONS['offsite_locations'].include? holding[:location_code]
    end
  end

  # Sometimes we want to only know what's ON-campus
  # (e.g., intercampus-delivery service)
  def onsite_holdings
    holdings.select do |holding|
      !is_offsite_location_code?(holding[:location_code])
      # !LOCATIONS['offsite_locations'].include? holding[:location_code]
    end
  end

  def populate_barcodes
    # Single array of barcodes from all holdings, all items
    barcodes = @holdings.collect do |holdings|
      holdings[:items].collect do |item|
        item[:barcode]
      end
    end.flatten.uniq

    @barcodes = barcodes
  end

  # Return the availability for the passed item.
  def get_item_availability(holding, item)
    # For Offsite items, always return SCSB availability
    #   (Not the FOLIO availability of the matching FOLIO item)
    if is_offsite_location_code?(holding[:location_code])
      self.fetch_scsb_availabilty unless @scsb_availability
      return @scsb_availability[item[:barcode]] if @scsb_availability.has_key?(item[:barcode])

      # No SCSB availability for an offsite item?
      # Something's wrong - either not yet accessioned at ReCAP or another problem.
      return ''
    end

    # fetch FOLIO availability for all holdings/items of this bib...
    self.fetch_folio_availability unless @folio_availability
    # ...and then pull out the availability for just the item of interest
    folio_item_status = @folio_availability[item[:item_id]]

    # Clancy houses Barnard Remote(bar,stor) and StarrStor (East Asian temporary)
    # If FOLIO says the item is Available, double-check with Clancy/CaiaSoft,
    # It may be missing from the shelf.
    if folio_item_status.eql?('Available') &&
       is_clancy_location_code?(holding[:location_code])
      # Clancy uses the CaiaSoft inventory management system
      caiasoft_itemstatus = Clancy::CaiaSoft::get_itemstatus(item[:barcode])
      status_string = caiasoft_itemstatus[:status] || ''
      if status_string == 'Item In at Rest'
        return 'Available'
      else
        item[:use_restriction] = status_string
        return status_string
      end
    end

    # If NOT Clancy/CaiaSoft, return FOLIO status
    return folio_item_status
  end

  # Fetch availability for each barcode from SCSB
  # @scsb_availability format:
  #   { barcode: availability, barcode: availability, ...}
  def fetch_scsb_availabilty
    if id.empty?
      Rails.logger.error "ERROR: fetch_scsb_availabilty() called with null id"
      return
    end

    # Default - assume this is Columbia offsite material
    institution = 'CUL'
    institution_id = id.to_s

    # But if it's a SCSB Id...
    if institution_id =~ /^SCSB\-/
      institution = 'SCSB'
      institution_id = institution_id.gsub(/SCSB-/, '')
    end

    @scsb_availability ||= Recap::ScsbRest.get_bib_availability(institution_id, institution) || {}
    Rails.logger.debug "fetch_scsb_availabilty(#{id}): #{@scsb_availability}"
    return @scsb_availability
  end

  # # Fetch availability for each barcode from Voyager (via clio-backend)
  # # @voyager_availability format:
  # #   { item_id: availability, item_id: availability, ...}
  # # where 'availability' is a simple string, 'Available' or 'Unavailable'
  # def fetch_voyager_availability
  #   @voyager_availability ||= Clio::BackendConnection.get_bib_availability(id) || {}
  # end

  def fetch_folio_availability
    @folio_availability = {}
    # Simple approach - for every item, lookup it's individual status
    @holdings.each do |holding|
      holding[:items].each do |item|
        item_id = item[:item_id]
        begin
          item_folio_details = Folio::Client.get_item(item_id)
          @folio_availability[item_id] = item_folio_details['status']['name']
        rescue => ex
          # Any error retrieving item availability?  Assume Unavailable.
          @folio_availability[item_id] = 'Unavailable'
        end
      end
    end

    return @folio_availability

    # This assumed that there was some clever way to gather item-status for
    # a set of items - but RTAC is broken/deprecated, and we don't know of another
    # API endpoint.
    # # The FOLIO Instance ID is in the 999$i
    # # BUT - we have bad data, with bogus occsional bogus 999 or even 999$i values.
    # # Examine every 999$i that we find, to see if it looks like a UUID
    # instance_uuid = nil
    # @marc_record.each_by_tag('999')  do |field_999|
    #   field_999.subfields.select { |sf| sf.code == 'i' }.each do |subfield|
    #     uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    #     if uuid_regex.match?(field_999['i'].downcase)
    #       instance_uuid = field_999['i']
    #     end
    #   end
    # end
    # return {} unless instance_uuid
    #
    # @folio_availability ||= Folio::Client.get_availability(instance_uuid) || {}
  end

  # For each of the barcodes in this record (@barcodes),
  # check to see if there's a TOC.
  # If so, add the toc URL to this record's tocs Hash:
  # {
  # 'CU12731471' => 'http://www.columbia.edu/cgi-bin/cul/toc.pl?CU12731471',
  #  ...etc...
  # }
  def fetch_tocs
    # SLOW FOR SERIALS WITH MANY MANY BARCODES
    # conn = Columbia::Web.open_connection()
    # @barcodes.each do |barcode|
    #   toc = Columbia::Web.get_toc_link(barcode, conn)
    #   if toc.present?
    #     tocs[barcode] = toc
    #   end
    # end
    # Hopefully faster?
    tocs = Columbia::Web.get_bib_toc_links(id) || {}
    @tocs = tocs
  end

  # # 10/2020 - UNUSED
  # def openurl
  #   openurl = {}
  #
  #   # The OpenURL keys are fixed by Illiad servce.
  #   # We re-purpose some fields for other purposes.
  #   # (E.g., "loadplace", "loandate")
  #   openurl[:title]      = title
  #   openurl[:author]     = author
  #   openurl[:publisher]  = pub_name
  #   openurl[:loanplace]  = pub_place
  #   openurl[:loandate]   = pub_date
  #   openurl[:isbn]       = isbn
  #   if issn.present?
  #     openurl[:issn]       = issn
  #     openurl[:genre]      = 'article'
  #   end
  #   openurl[:CallNumber] = call_number
  #   openurl[:edition]    = edition
  #   # "External Service Provider Number"
  #   # (Illiad only wants the numeric portion, not any ocm/ocn prefix)
  #   openurl[:ESPNumber]  = oclc_number.gsub(/\D/, '')
  #   openurl[:sid]        = 'CLIO OPAC'
  #   openurl[:notes]      = 'https://clio.columbia.edu/catalog/' + id
  #
  #   openurl_string = openurl.map do |key, value|
  #     # puts "key=[#{key}] value=[#{value}]"
  #     "#{key}=#{CGI.escape(value)}"
  #   end.join('&')
  #
  #   # puts "-- openurl params as string:"
  #   # puts openurl_string
  #   # puts "--"
  #   openurl_string
  # end

  # Trim punctuation from MARC fields
  # (copied directly from https://github.com/traject/traject)
  def trim_punctuation(str = shift)
    # If something went wrong and we got a nil, just return it
    return str unless str

    # trailing: comma, slash, semicolon, colon (possibly preceded and followed by whitespace)
    str = str.sub(/ *[ ,\/;:] *\Z/, '')

    # trailing period if it is preceded by at least three letters (possibly preceded and followed by whitespace)
    str = str.sub(/( *[[:word:]]{3,})\. *\Z/, '\1')

    # single square bracket characters if they are the start and/or end
    #   chars and there are no internal square brackets.
    str = str.sub(/\A\[?([^\[\]]+)\]?\Z/, '\1')

    # trim any leading or trailing whitespace
    str.strip!

    str
  end

  # Given a string location code,
  # return True/False whether the location code is offsite.
  def is_offsite_location_code?(location_code = shift)
    return unless location_code and location_code.instance_of?(String)

    # Any location code that begins with "off" is offsite
    return true if location_code.match(/^off/i)
    # All SCSB locations are offsite
    return true if location_code.match(/^scsb/i)

    # Anything else is NOT offsite
    return false
  end

  # Is this material available in a CaiaSoft-managed repository?
  def is_clancy_location_code?(location_code = shift)
    return unless location_code and location_code.instance_of?(String)

    return true if APP_CONFIG['clancy_locations'].include?(location_code)

    return false
  end

  # ---------------------------
  # Special Collections Support
  # ---------------------------

  def get_aeon_dates_from_bib()
    field_008 = @marc_record['008']
    return nil unless field_008

    data       = field_008.value
    start_year = data[7, 4]
    end_year   = data[11, 4]

    return nil unless start_year && start_year.match?(/[0-9u]{4}/)

    return start_year unless end_year && end_year.match?(/[0-9u]{4}/) && end_year != '9999'

    "#{start_year} #{end_year}"
  end

  # 506 - Restrictions on Access Note
  def get_aeon_access_restrictions_from_bib()
    return '' unless @marc_record && @marc_record['506']

    subfieldA = @marc_record['506']['a'] || ''

    @marc_record.fields('506').each do |field|
      next unless (restriction = field['a'])
      return 'UNPROCESSED' if restriction.match?(/unprocessed/i)
    end
  end

  def get_aeon_format_from_bib()
    leader_code = @marc_record.leader[6, 2]

    format_category, position_008 =
      case leader_code
      when /a[macd]/  then ["Book", 23]
      when /a[sib]/   then ["Continuing Resource", 23]
      when /^[ht]/    then ["Book", 23]
      when /^m/       then ["Computer File", 23]
      when /^[gkor]/  then ["Visual Material", 29]
      when /^[cd]/    then ["Score", 23]
      when /^[ij]/    then ["Recording", 23]
      when /^[ef]/    then ["Map", 29]
      when /^[bp]/    then ["Mixed", 23]
        else [nil, nil]
       end

    return format_category unless position_008 && (field_008 = @marc_record['008'])

    code = field_008.value[position_008]
    format_code = FORMAT_008_CODES[code]

    if format_code
      "#{format_category}; #{format_code}"
    else
      format_category
    end
  end

  FORMAT_008_CODES = {
    'a' => "Microfilm",
    'b' => "Microfiche",
    'c' => "Microopaque",
    'd' => "Large print",
    'f' => "Braille",
    'o' => "Online",
    'q' => "Direct electronic",
    'r' => "Print reproduction",
    's' => "Electronic"
  }.freeze

  # Untested code.  I asked for an example bib to test this,
  # and was told that support for this field was unnecessary.
  #
  # def get_aeon_series_from_bib()
  #   # Try 490$a first
  #   if (field = @marc_record['490']) && (subfield_a = field['a'])
  #     return subfield_a
  #   end
  #
  #   # Fallback to 800, 810, 811, 830
  #   %w[800 810 811 830].each do |tag|
  #     if (field = @marc_record[tag])
  #       return field.as_string('abcdenpqtv')
  #     end
  #   end
  #
  #   nil
  # end
end
