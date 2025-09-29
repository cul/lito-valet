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
      # I want these for the form:
      # - Holding Call Number
      # - Holding Copy Number
      # - Item Enumeration
      # - Item Barcode (not displayed)
      locals = {
        bib_record: bib_record,
        container_list: get_container_list(bib_record)
      }

    end

    
    def build_service_url(params, bib_record, current_user)
      # If a finding-aid exists, redirect to the finding aid
      if finding_aid_link = bib_record.finding_aid_link()
        Rails.logger.debug("#{bib_record.id} -- has finding aid link")
        return finding_aid_link
      end
      
      # If there is a single container (and no finding aid),
      # then set the requested container to be that single container (item)
      container_list = get_container_list(bib_record)
      if container_list.size == 1
        Rails.logger.debug("#{bib_record.id} -- has only single container")
        params['item_id'] = container_list.first[:item_id]
      end
      
      aeon_url = build_aeon_openurl(bib_record, params['item_id'])

      return aeon_url
    end


    def get_container_list(bib_record)
      container_list = []

      special_collections_holdings = get_special_collections_holdings(bib_record)
      special_collections_holdings.each do |holding|
        holding[:items].each do |item|
          container = {}
          # raise
          container[:item_id]         = item[:item_id]
          container[:call_number]     = holding[:display_call_number]
          container[:enum_chron]      = item[:enum_chron]
          container[:barcode]         = item[:barcode]
          container[:label] = [ holding[:display_call_number], item[:enum_chron] ].join(' ')
          container_list << container
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
    

    # requested_container_id is the item_id (a container == an item)
    def build_aeon_openurl(bib_record, requested_container_id)
      aeon_params = {}

      # Bib-level parameters
      aeon_params['ReferenceNumber']      = bib_record.id
      aeon_params['ItemAuthor']           = bib_record.author
      aeon_params['ItemTitle']            = bib_record.title
      # ???
      # aeon_params['subtitle']             =
      aeon_params['ItemPlace']            = bib_record.pub_place
      aeon_params['ItemPublisher']        = bib_record.pub_name
      aeon_params['ItemDate']             = bib_record.pub_date
      # ???
      # aeon_params['format']               = Iteminfo1
      # aeon_params['access_restrictions']  = Iteminfo3
      # Bib-Level call-number of Holding-level Call Number?
      # aeon_params['CallNumber']               = bib_record.call_number
      # ???
      # aeon_params['collection']           = ItemIssue

      # Holding/Item-level parameters
      # - find the specific Holding/Item details for the container being requested
      bib_record.holdings.each do |holding|
        holding[:items].each do |item|
          next unless item[:item_id] == requested_container_id

          aeon_params['Location']     = holding[:location_display]
          aeon_params['CallNumber']   = holding[:display_call_number]
          aeon_params['ItemVolume']   = item[:enum_chron]
          aeon_params['ItemNumber']   = item[:barcode]
          # 'locations' is an array of key/value pairs,
          # key is the location code, value is the Aeon "Site"
          special_collections_locations = @service_config[:locations]
          aeon_params['Site']         = special_collections_locations[ holding[:location_code] ]
        end
      end
      
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


