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

    @scsb_availability = {}
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
      bib_id:  id,
      title:   title,
      author:  author
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

  def voyager?
    owningInstitution == 'CUL' && id.match(/^\d+$/)
  end

  # def title
  #   title ||= []
  #   "abcfghknps".split(//).each do |subfield|
  #     if @marc_record['245']
  #       title << @marc_record['245'][subfield]
  #     end
  #   end
  #   return title.compact.join(' ')
  # end
  #
  # def author
  #   author ||= []
  #   ['100', '110', '111'].each do |field|
  #     next unless @marc_record[field]
  #     'abcdefgjklnpqtu'.split(//).each do |subfield|
  #       author << @marc_record[field][subfield]
  #     end
  #     # stop once the 1st possible field is found & processed
  #     break
  #   end
  #   return author.compact.join(' ')
  # end

  def title
    return '' unless @marc_record && @marc_record['245']
    subfieldA = @marc_record['245']['a'] || ''
    subfieldB = @marc_record['245']['b'] || ''
    title = subfieldA.strip
    title += " #{subfieldB.strip}" if subfieldB.present?
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
    return call_number_050 || ''
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
  end

  # Bibs can have multiple ISBNs for different formats,
  # and 020$a can have ISBN together with notes "123 (paperback)"
  def isbn
    isbns = @marc_record.fields('020').map do |field|
      StdNum::ISBN.normalize(field['a'])
    end
    isbns.compact
  end

  def issn
    issns = @marc_record.fields('022').map do |field|
      StdNum::ISSN.normalize(field['a'])
    end
    # StdNum module returns digits only.
    # Map to hyphenated form (NNNN-NNNN)
    issns.compact.map do |digits|
      digits[0..3] + '-' + digits[4..7]
    end
  end

  def populate_owningInstitution
    return 'CUL' unless holdings.present?

    case holdings.first[:location_code]
    when 'scsb-nypl', 'scsbnypl'
      @owningInstitution = 'NYPL'
    when 'scsb-pul', 'scsbpul'
      @owningInstitution = 'PUL'
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
      holdings[mfhd_id] = {
        mfhd_id:                  mfhd_id,
        location_display:         tag852['a'],
        location_code:            tag852['b'],
        display_call_number:      tag852['h'],
        items:                    []
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
        enum_chron:         item_field['3']
        # customer_code:      item_field['z']
      }
      # Store this item hash in the apppropriate Holding
      mfhd_id = item_field['0']
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
      LOCATIONS['offsite_locations'].include? holding[:location_code]
    end
  end

  # Sometimes we want to only know what's ON-campus
  # (e.g., intercampus-delivery service)
  def onsite_holdings
    holdings.select do |holding|
      !LOCATIONS['offsite_locations'].include? holding[:location_code]
    end
  end

  # def barnard_remote_holdings
  #   barnard_config = APP_CONFIG['barnard']
  #   die "Missing barnard configuration!" unless
  #     barnard_config.present? && barnard_config['remote_location_code'].present?
  #
  #   holdings.select do |holding|
  #     holding[:location_code] == barnard_config['remote_location_code']
  #   end
  # end

  def populate_barcodes
    # Single array of barcodes from all holdings, all items
    barcodes = @holdings.collect do |holdings|
      holdings[:items].collect do |item|
        item[:barcode]
      end
    end.flatten.uniq

    @barcodes = barcodes
  end

  # Fetch availability for each barcode from SCSB
  # @scsb_availability format:
  #   { barcode: availability, barcode: availability, ...}
  def fetch_scsb_availabilty
    @scsb_availability = Recap::ScsbRest.get_bib_availability(owningInstitutionBibId, owningInstitution) || {}

    # @available_item_count = @scsb_availability.select{ |barcode, availability_status|
    #   availability_status == 'Available'
    # }.count
  end

  # Fetch availability for each barcode from Voyager (via clio-backend)
  # @voyager_availability format:
  #   { item_id: availability, item_id: availability, ...}
  def fetch_voyager_availability
    @voyager_availability ||= Clio::BackendConnection.get_bib_availability(id) || {}
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

  def openurl
    openurl = {}

    # The OpenURL keys are fixed by Illiad servce.
    # We re-purpose some fields for other purposes.
    # (E.g., "loadplace", "loandate")
    openurl[:title]      = title
    openurl[:author]     = author
    openurl[:publisher]  = pub_name
    openurl[:loanplace]  = pub_place
    openurl[:loandate]   = pub_date
    openurl[:isbn]       = isbn
    if issn.present?
      openurl[:issn]       = issn
      openurl[:genre]      = 'article'
    end
    openurl[:CallNumber] = call_number
    openurl[:edition]    = edition
    # "External Service Provider Number"
    # (Illiad only wants the numeric portion, not any ocm/ocn prefix)
    openurl[:ESPNumber]  = oclc_number.gsub(/\D/, '')
    openurl[:sid]        = 'CLIO OPAC'
    openurl[:notes]      = 'https://clio.columbia.edu/catalog/' + id

    openurl_string = openurl.map do |key, value|
      # puts "key=[#{key}] value=[#{value}]"
      "#{key}=#{CGI.escape(value)}"
    end.join('&')

    # puts "-- openurl params as string:"
    # puts openurl_string
    # puts "--"
    openurl_string
  end

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

  # OpenURL generation code, from /wwws/cgi/cul/forms/illiad CGI
  # sub printout {
  #
  #   my $out = shift;
  #
  #   if ($out->{'issn'})      {$open .= "genre=article&issn="       . $out->{'issn'}      . "&"};
  #   if ($out->{'LCcall'})    {$open .= "CallNumber=" . $out->{'LCcall'}    . "&"};
  #   if ($out->{'isbn'})      {$open .= "isbn="       . $out->{'isbn'}      . "&"};
  #   if ($out->{'edition'})   {$open .= "edition="    . $out->{'edition'}   . "&"};
  #   if ($out->{'author'})    {$open .= "author="     . $out->{'author'}    . "&"};
  #   if ($out->{'oclc'})      {$oclc = $out->{'oclc'};  $oclc =~ s/\D//g;
  #                             $open .= "ESPNumber="  . $oclc . "&"};
  #   if ($out->{'publisher'}) {$open .= "publisher="  . $out->{'publisher'} . "&"};
  #   if ($out->{'pub_place'}) {$open .= "loanplace="  . $out->{'pub_place'} . "&"};
  #   if ($out->{'pub_date'})  {$date = $out->{'pub_date'}; $date =~ s/\D//g;
  #                             $open .= "loandate="   . $date . "&"};
  #   $open .= "title=" . $out->{'title'} . "&";
  #   $open .= "sid=CLIO OPAC&notes=https://clio.columbia.edu/catalog/$bib_id&";
  #
  #
  # $open =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  #
  #
  # }

  # def public_locations
  #   # basic set of public delivery locations
  #   basic_set = ['AR', 'BL', 'UT', 'BS', 'BU', 'EA', 'HS', 'CJ', 'GS', 'LE', 'ML', 'MR', 'CA', 'SW']
  #
  #   locations = {
  #     'OFF AVE'   => { default: 'AR', available: ['AR']},
  #     'OFF BIO'   => { default: 'CA', available: basic_set},
  #     'OFF BMC'   => { default: 'CV', available: ['CV']},
  #     'OFF BSSC'  => { default: 'BS', available: ['BS']},
  #     'OFF BUS'   => { default: 'BS', available: basic_set},
  #     'OFF CHE'   => { default: 'CA', available: basic_set},
  #     'OFF DOCS'  => { default: 'LE', available: basic_set},
  #     'OFF EAL'   => { default: 'EA', available: basic_set},
  #     'OFF EAN'   => { default: 'EA', available: ['EA']},
  #     'OFF EAX'   => { default: 'EA', available: basic_set},
  #     'OFF ENG'   => { default: 'CA', available: basic_set},
  #     'OFF FAX'   => { default: 'AR', available: ['AR']},
  #     'OFF GLG'   => { default: 'CA', available: basic_set},
  #     'OFF GLX'   => { default: 'BU', available: basic_set},
  #     'OFF GSC'   => { default: 'GS', available: basic_set},
  #     'OFF HSL'   => { default: 'HS', available: basic_set},
  #     'OFF HSR'   => { default: 'HS', available: basic_set},
  #     'OFF JOU'   => { default: 'CJ', available: basic_set},
  #     'OFF LEH'   => { default: 'LE', available: basic_set},
  #     'OFF LES'   => { default: 'LE', available: ['LE']},
  #     'OFF MAT'   => { default: 'ML', available: basic_set},
  #     'OFF MRR'   => { default: 'CF', available: ['CF']},
  #     'OFF MSC'   => { default: 'MR', available: ['MR']},
  #     'OFF MSR'   => { default: 'MR', available: ['MR']},
  #     'OFF MUS'   => { default: 'MR', available: basic_set},
  #     'OFF MVR'   => { default: 'MR', available: ['MR']},
  #     'OFF PHY'   => { default: 'CA', available: basic_set},
  #     'OFF PSY'   => { default: 'CA', available: basic_set},
  #     'OFF REF'   => { default: 'BU', available: basic_set},
  #     'OFF SCI'   => { default: 'CA', available: basic_set},
  #     'OFF SWX'   => { default: 'SW', available: basic_set},
  #     'OFF UNR'   => { default: 'UT', available: ['UT']},
  #     'OFF UTMRL' => { default: 'UT', available: ['UT']},
  #     'OFF UTN'   => { default: 'UT', available: basic_set},
  #     'OFF UTP'   => { default: 'UT', available: ['UT']},
  #     'OFF UTS'   => { default: 'UT', available: basic_set},
  #     'OFF WAR'   => { default: 'AR', available: basic_set}
  #   }
  # end
  #
  # def location_labels
  #   labels = {
  #   'BC' => 'Bibliographic Control',
  #   'BT' => 'Butler Preservation',
  #   'CI' => 'Interlibrary Loan<',
  #   'CV' => 'Milstein Reserves',
  #   'MP' => 'Monographic Recon -- for MRP',
  #   'MZ' => 'ReCAP Coordinator',
  #   'IL' => 'ReCAP Interlibrary Loan',
  #   'AR' => 'Avery Library',
  #   'BL' => 'Barnard Library',
  #   'UT' => 'Burke Library (UTS)',
  #   'BS' => 'Business/Econ Library',
  #   'BU' => 'Butler Library',
  #   'EA' => 'East Asian Library',
  #   'EN' => 'Engineering Library',
  #   'GS' => 'Lamont-Doherty Earth Observatory',
  #   'HS' => 'Health Sciences Library',
  #   'CJ' => 'Journalism Library',
  #   'LE' => 'Lehman Library',
  #   'RH' => 'Lehman Suite',
  #   'ML' => 'Mathematics Library',
  #   'CF' => '401 Butler Library (Microform Reading Room)',
  #   'MR' => 'Music &amp; Arts Library',
  #   'RS' => 'Rare Book Library',
  #   'CA' => 'Science &amp; Engineering Lib (NWC Building)',
  #   'SW' => 'Social Work Library'
  # }
  # end
end
