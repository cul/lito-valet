# 
# Special Collections requests - currently Atlas Systems Aeon
# 
# examples:
#   https://clio.columbia.edu/catalog/10161745
#   https://clio.columbia.edu/catalog/2268048
#   https://clio.columbia.edu/catalog/16682497
#   https://clio.columbia.edu/catalog/1393484
# 
# Sample Records:
#   http://cliobeta.columbia.edu:3002/special_collections/2105643
#   http://cliobeta.columbia.edu:3002/special_collections/in00033882717
# https://clio-test.cul.columbia.edu/catalog/6198548
# https://clio-test.cul.columbia.edu/catalog/2598313

#   http://cliobeta.columbia.edu:3002/special_collections/6198548
#   http://cliobeta.columbia.edu:3002/special_collections/2598313

module Service
  class SpecialCollections < Service::Base

    # Is this bib eligible for a Special Collections request?
    # Only if it has a holding in a Special Collections location.
    def bib_eligible?(bib_record = nil)
      return false unless bib_record
 
      special_collections_holdings = get_special_collections_holdings(bib_record)
      if special_collections_holdings.size.zero?
        self.error = "This record has no holdings in any Special Collections library.
        <br><br>
        Requests can only be made for Special Collections items."
        return false
      end

      return true
    end


    # Is this service a "form" service or a "bounce" service?
    # For Special Collections it depends on the details.
    # If there's a finding-aid, it's a bounce.
    # If there's a single container, it's a bounce.
    # If there are multiple containers, it's a form.
    def service_type?(bib_record)
      return 'bounce' if bib_record.finding_aid_link()

      container_list = get_container_list(bib_record)
      return 'bounce' if container_list.size == 1

      return 'form'
    end

    # Build necessary data params to build a container list
    def setup_form_locals(params, bib_record, current_user)
      locals = {
        bib_record: bib_record,
        container_list: get_container_list(bib_record)
      }
    end

    # Special Collections can act as a bounce or as a form
    # "bounce" will call this, without params, to get a redirect URL
    # "form" will call this with form params to get the redirect URL
    def build_service_url(params, bib_record, current_user)
      # If a finding-aid exists, redirect to the finding aid
      if finding_aid_link = bib_record.finding_aid_link()
        Rails.logger.debug("#{bib_record.id} -- redirecting to finding aid link: #{finding_aid_link}")
        return finding_aid_link
      end

      # We'll need container details to build the Aeon OpenURL
      container_list = get_container_list(bib_record)
      
      # If there is a single container (and no finding aid),
      # then set the requested container to be that single container (item)
      if container_list.size == 1
        Rails.logger.debug("#{bib_record.id} -- has only single container")
        return build_aeon_openurl(bib_record, container_list.first)
      end
      
      # If we got here from a form post, then container_id will identify
      # the user-selected container (either a holding or an item)
      if params.key?('container_id')
        Rails.logger.debug("#{bib_record.id} -- selected container id #{params['container_id']}")
        container_list.each do |container|
          next unless container[:container_id] == params['container_id']
          return build_aeon_openurl(bib_record, container)
        end
      end
      
      self.error = "Unexpected error in build_service_url() - bib #{bib_record.id}"
      return 
    end


    def get_container_list(bib_record)
      # app_config 'locations' is a list of key/value pairs,
      # key is the location code, value is the Aeon "Site" - which we'll need
      sites_hash = @service_config[:locations]

      container_list = []

      special_collections_holdings = get_special_collections_holdings(bib_record)
      special_collections_holdings.each do |holding|
        
        # Usually patrons request a specific item from a list of items (containers / boxes)
        # but for _some_ locations, librarians only want overall holding-level requests
        request_entire_holding = false
        request_entire_holding = true if holding[:location_code] == 'rbms'
        request_entire_holding = true if holding[:location_code].start_with?('uts')
        request_entire_holding = true if holding[:location_code] == 'off,uta'
        
        # HOLDINGS WITH NO ITEMS (OR locations where we only want holdings-level requests)
        # We'll create a single container, made up of only holding level details
        # (and container_id will the Holding UUID)
        if holding[:items].blank? or request_entire_holding
          container = {}
          # container id, display label
          container[:container_id]      = holding[:mfhd_id]
          container[:label]             = holding[:display_call_number]
          # holding details
          container[:location_code]     = holding[:location_code]
          container[:site]              = sites_hash[ holding[:location_code] ]
          container[:call_number]       = holding[:display_call_number]
          container_list << container
          
        # HOLDINGS WITH ITEMS - EACH ITEM IS A CONTAINER
        # We'll create a container for each item, made up of holding+item level details
        # (and each container_id will the Item UUID)
        else
          holding[:items].each do |item|
            container = {}
            # container id, display label
            container[:container_id]    = item[:item_id]
            container[:label] = [ holding[:display_call_number], item[:enum_chron] ].join(' ')
            # holding details
            container[:location_code]   = holding[:location_code]
            container[:site]            = sites_hash[ holding[:location_code] ]
            container[:call_number]     = holding[:display_call_number]
            # item details
            container[:enum_chron]      = item[:enum_chron]
            container[:barcode]         = item[:barcode]
            container_list << container
          end
        end
      end

      container_list.sort_by! { |container| natural_sort_key(container[:label]) }

      return container_list
    end

    def natural_sort_key(str)
      # Always work with a string
      label = str.to_s.downcase

      # Split the string into chunks of digits and non-digits
      parts = label.split(/(\d+)/)

      # Convert digit chunks to integers, leave text chunks as strings
      key = parts.map do |part|
        if part.match?(/^\d+$/)
          part.to_i
        else
          part
        end
      end

      # multi-token key, can be used directly in sort_by()
      key
    end


    def get_special_collections_holdings(bib_record)
      # This service is different from the others,
      # 'locations' is an array of key/value pairs,
      # key is the location code, value is the Aeon "Site"
      special_collections_locations = @service_config[:locations].keys
      
      special_collections_holdings = bib_record.holdings.select do |holding|
        special_collections_locations.include?( holding[:location_code] )
      end
    end
    

    # A "container" is metadata about what's being requested.
    # It may be item-level details, or it may be
    # holding-level details for a holding with no cataloged items.
    # Field-names are sometimes semantically unrelated to the field-values,
    # because Aeon is using keys from the OpenURL standard, which don't always fit.
    def build_aeon_openurl(bib_record, container)
      aeon_params = {}

      # Bib-level parameters
      aeon_params['ReferenceNumber'] = bib_record.id
      aeon_params['ItemAuthor']      = bib_record.author
      aeon_params['ItemTitle']       = bib_record.title
      # ItemSubTitle == "Series"
      # aeon_params['subtitle']             =  ItemSubTitle
      aeon_params['ItemPlace']       = bib_record.pub_place
      aeon_params['ItemPublisher']   = bib_record.pub_name
      aeon_params['ItemDate']        = bib_record.get_aeon_dates_from_bib()
      aeon_params['Iteminfo1']       = bib_record.get_aeon_format_from_bib()
      aeon_params['Iteminfo3']       = bib_record.get_aeon_access_restrictions_from_bib()

      # ItemIssue == "Book Collection or Oral History Project Name"
      # aeon_params['ItemIssue']    = container[:location_code]

      aeon_params['Location']     = container[:location_code]
      aeon_params['CallNumber']   = container[:call_number]
      if aeon_params['CallNumber'].blank?
        # Use bib-level call-number if no holding-level value was found
        aeon_params['CallNumber']   = bib_record.call_number
      end
      
      aeon_params['ItemVolume']   = container[:enum_chron]
      aeon_params['ItemNumber']   = container[:barcode]
      aeon_params['Site']         = container[:site]

      return build_aeon_login_url(aeon_params)
    end
    
    def build_aeon_login_url(aeon_params)
      # Add some fixed key/values to the params
      aeon_params['Action']       = '10'
      aeon_params['Form']         = '20'
      aeon_params['Value']        = 'GenericRequestAll'
      aeon_params['DocumentType'] = 'All'

      aeon_login_page = 'https://aeon.cul.columbia.edu?'
      
      return aeon_login_page + aeon_params.to_query
    end
    



  end
end


