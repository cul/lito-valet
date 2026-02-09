# Called like this from the controller:
#   solr_connection = Clio::SolrConnection.new()
#   marc = solr_connection.retrieve_marc(bib_id)
module Clio
  class SolrConnection
    MARC_FIELD = 'marc_display'.freeze

    def initialize
      solr_args = APP_CONFIG['solr_connection_details']
      raise 'Solr config missing!' unless solr_args.present?
      raise "Solr config missing 'url'" unless solr_args.key?(:url)

      Rails.logger.debug "Clio::SolrConnection#initialize: solr_args:#{solr_args}"
      @solr_connection = RSolr.connect url: solr_args[:url]
    end

    def retrieve_marcxml_by_query(query = nil)
      raise 'retrieve_marcxml_by_query() needs query' unless query.present?

      solr_doc = fetch_solr_doc_by_query(query)
      if solr_doc.blank?
        Rails.logger.info "Clio::Solr::retrieve_marcxml_by_query(#{query}) retrieved nil solr_doc!"
        return nil
      end

      marc = solr_doc_to_marcxml(solr_doc)
      if marc.blank?
        Rails.logger.info "Clio::Solr::retrieve_marcxml_by_query(#{query}) retrieved nil marc!"
      end
      marc
    end

    def fetch_solr_doc_by_query(query = nil)
      raise 'fetch_solr_doc_by_query() needs {key => value} query' unless
          query.present? && query.is_a?(Hash) && query.size == 1

      # query hash { bib_id: 1234 } becomes string "bibid:1234"
      q = "#{query.keys.first}:\"#{query.values.first}\""

      # Use the 'document' handler to fetch a specific document
      #   e.g., http://SERVER:PORT/solr/CORE/select?qt=document&id=1234
      params = { qt: 'document', fl: "id,#{MARC_FIELD}", q: q }

      Rails.logger.debug "- fetch_solr_doc_by_query(#{query}), Solr params #{params.inspect}"
      response = @solr_connection.get 'select', params: params
      Rails.logger.debug "Solr response status: #{response['responseHeader']['status']}"

      # May be nil if no doc not was found
      solr_doc = response['response']['docs'].first
      solr_doc
    end

    def solr_doc_to_marcxml(solr_doc = nil)
      raise 'solr_doc_to_marcxml() needs solr_doc' unless solr_doc.present?

      # May be nil if this doc doesn't have this field
      solr_doc[MARC_FIELD]
    end
  end
end
