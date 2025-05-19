# 
# Special Collections requests - currently Atlas Systems Aeon
# 
# examples:
#   https://clio.columbia.edu/catalog/10161745
#   https://clio.columbia.edu/catalog/2268048
#   https://clio.columbia.edu/catalog/16682497
#   https://clio.columbia.edu/catalog/1393484
# 
module Service
  class SpecialCollections < Service::Base

    # Is this bib eligible for a Special Collections request?
    # Only if it has a holding in a Special Collections location.
    def bib_eligible?(bib_record = nil)
      return false unless bib_record
 
      # 4/30 - SOLR DOES NOT YET HAVE LOCATION CODE,
      # JUST RETURN TRUE FOR NOW
      return true
 
      special_collections_holdings = get_special_collections_holdings(bib_record)
      if special_collections_holdings.size.zero?
        self.error = "This record has no holdings in any Special Collections library.
        <br><br>
        Requests can only be made for Special Collections items."
        return false
      end
 
      # Any further checks after confirming location?
      # If not, then this bib is eligible 
      return true
    end


    # Is this service a "form" service or a "bounce" service?
    # For Special Collections it depends on the details.
    # If there's a finding-aid, it's a bounce.
    # If there's a single container, it's a bounce.
    # If there are multiple containers, it's a form.
    def service_type?(bib_record)
      return 'bounce' if bib_record.finding_aid_link()

      container_list = bib_record.container_list()
      return 'bounce' if container_list.size == 1

      return 'form'
    end

    # Build necessary data params to build a container list
    def setup_form_locals(params, bib_record, current_user)
      # I need these for the form:
      # - Holding Call Number
      # - Holding Copy Number
      # - Item Enumeration
      # - Item Barcode (not displayed)
      # What API calls supply these details?

    end
  
    def build_service_url(params, bib_record, current_user)
      if finding_aid_link = bib_record.finding_aid_link()
        return finding_aid_link
      end
      
      # TODO - build openurl 

      return "https://example.com"
    end


    def container_list
      container_list = []

      special_collections_holdings = get_special_collections_holdings(bib_record)
      special_collections_holdings.each do |holding|
        # TODO - add each item to container list
      end

      return container_list
    end


    def get_special_collections_holdings(bib_record)
      special_collections_holdings = bib_record.holdings.select do |holding|
        @service_config[:locations].include?( holding[:location_code] )
      end
    end
    
    
  end
end


