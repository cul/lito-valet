module Service
  class IllScan < Service::Base

    # Is the current patron allowed to use the ILL Scan service?
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

    def build_service_url(params, bib_record, current_user)
      
      # FIRST - process the campus triage form.
      campus = params['campus']
      # TC - Teachers College Library
      return 'https://resolver.library.columbia.edu/tc-ill' if campus == 'tc'

      # Otherwise, proceed with a redirect to OCLC ILLiad

      # MBUTS - Morningside, Barnard, UTS - use the default URL
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      # MCC - Medical Center Campus, a.k.a., HSL - use the ZCH URL
      illiad_base_url = APP_CONFIG[:illiad_base_url_zch] if campus == 'MCC'

      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      illiad_full_url = Oclc::Illiad.build_full_url(illiad_base_url, illiad_params)
      
      return illiad_full_url
    end


    private

    # def get_illiad_full_url(illiad_base_url, illiad_params)
    #   illiad_url_with_params = illiad_base_url + '?' + illiad_params.to_query
    #
    #   # Patrons always access Illiad through our CUL EZproxy
    #   ezproxy_url = APP_CONFIG[:ezproxy_login_url]
    #
    #   illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params
    #
    #   return illiad_full_url
    # end
    
    
    def get_illiad_params_explicit(bib_record, current_user)
      illiad_params = Oclc::Illiad.get_default_params(current_user, bib_record)
      
      # Action=10 tells Illiad that we'll pass the Form ID to use
      illiad_params['Action']    = '10'
      # use "CitedIn" as a routing tag, so staff know the origin of the request
      illiad_params['CitedIn']      = 'CLIO_OPAC-ILL'

      # ===> These params differ between Books and Articles
      if bib_record.issn.present?
        # If there's an ISSN, make an Article request (ArticleRequest.html)
        illiad_params['Form']        = '22'
        extra_article_params = Oclc::Illiad.get_article_params(bib_record)
        illiad_params.merge!(extra_article_params)
      else
        # Otherwise, make a Book Chapter request (BookChapterRequest.html)
        illiad_params['Form']        = '23'
        extra_book_chapter_params = Oclc::Illiad.get_book_chapter_params(bib_record)
        illiad_params.merge!(extra_book_chapter_params)
      end
      
      Oclc::Illiad.clean_hash_values(illiad_params)

      return illiad_params
    end
      
  end
end

