module Service
  class BorrowDirect < Service::Base

    # If a patron has any disqualifying condition (fines, blocks, etc.), 
    # then they'll have a "_blocked" affil, and won't match the permitted_affils list
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    # Columbia's Borrow Direct service had been implemented by OCLC's Relais ILL,
    # but was migrated to Project ReShare in 2022
    def build_service_url(_params, bib_record, current_user)
      # If we're configured to still use Relais
      if @service_config[:backend] && @service_config[:backend] == 'relais'
        return relais_build_service_url(_params, bib_record, current_user)
      end

      # Build a query URL against ReShare
      reshare_base_url = APP_CONFIG[:reshare_base_url]
      return false unless reshare_base_url
      
      # Support redirect to BorrowDirect landing page without any bib data
      return reshare_base_url unless bib_record.present?
      
      # Or, pass along a query to try to pull up the searched-for material
      query = reshare_build_query(bib_record)
      return false unless query

      # Build ReShare-speific authentication parameters - WIP
      # auth_params = "&req_id=" + current_user.login + "&res.org=ISIL%3AUS-NNC"
      # return reshare_base_url + '/Search/Results?' + query + auth_params

      # raise
      return reshare_base_url + '/Search/Results?' + query

    end
    
    def reshare_build_query(bib_record)
      return unless bib_record

      if bib_record.issn.present?
        # Query by ISSN
        query = 'type=ISN&lookfor=' + bib_record.issn.first
      elsif bib_record.isbn.present?
        # Query by ISBN
        query = 'type=ISN&lookfor=' + bib_record.isbn.first
      else
        # Query by Title
        query = 'type0[]=Title&lookfor0[]="' + CGI.escape(bib_record.title_brief) + '"'
        # Query by Title and Author
        if bib_record.author.present?
          query += '&type0[]=Author&lookfor0[]="' + CGI.escape(bib_record.author)
          query += '"&join=AND'
        end
      end
      
      return query
    end
    
    ######################################
    #####    LEGACY - RELAIS SUPPORT #####
    ######################################

    # When Borrow Direct bounces to Relais D2D,
    # we need the following fields:
    #   LS - Library Symbol (hardcoded:  COLUMBIA)
    #   PI - Patron Identifier (Voyager Barcode)
    #   query - query by isbn, issn, or title/author, see:
    #   https://relais.atlassian.net/wiki/spaces/ILL/pages/132579329/Using+other+discovery+tools
    #   A full example is:
    # https://bd.relaisd2d.com/?LS=COLUMBIA&PI=123456789&query=ti%3D%22Piotr%22+and+au%3D%22Sokorski%2C+Wodzimierz%22
    #
    def relais_build_service_url(_params, bib_record, current_user)
      url = 'https://bd.relaisd2d.com/'
      url += '?LS=COLUMBIA'
      url += '&PI=' + current_user.barcode
      
      # Support redirect to BorrowDirect landing page without any bib data
      if bib_record.present?
        url += '&query=' + relais_build_query(bib_record)
      end

      return url
    end

    def relais_build_query(bib_record)
      return '' unless bib_record
      
      query = ''
      if bib_record.issn.present?
        query = 'issn=' + bib_record.issn.first
      elsif bib_record.isbn.present?
        query = 'isbn=' + bib_record.isbn.first
      else
        query = 'ti="' + bib_record.title_brief + '"'
        if bib_record.author.present?
          query += ' and au="' + bib_record.author + '"'
        end
      end
      relais_escape(query)
    end

    def relais_escape(string)
      # standard Rails CGI param escaping...
      string = CGI.escape(string)
      # ...but then also use %20 instead of + for spaces
      string.gsub!(/\+/, '%20')
      string
    end
    ######################################
    ######################################
    ######################################

  end
end
