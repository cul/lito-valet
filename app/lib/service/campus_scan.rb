module Service
  class CampusScan < Service::Base

    # Is the current patron allowed to use the Campus Scan service?
    def patron_eligible?(current_user = nil)
      return false unless current_user && current_user.affils

      permitted_affils = @service_config[:permitted_affils] || []
      permitted_affils.each do |affil|
        return true if current_user.affils.include?(affil)
      end
      return false
    end

#       http://cliobeta.columbia.edu:3002/campus_scan/123


    def build_service_url(params, bib_record, current_user)
      
      # FIRST - process the campus triage form.
      campus = params['campus']
      # TC - Teachers College Library
      # return 'https://library.tc.columbia.edu/p/request-materials' if campus == 'tc'
      return 'https://library.tc.columbia.edu/services' if campus == 'tc'

      # Otherwise, proceed with a redirect to OCLC ILLiad
      # MCC - Medical Center Campus, a.k.a., HSL
      # MBUTS - Morningside, Barnard, UTS

      # illiad_base_url = @service_config[:illiad_base_url]
      illiad_base_url = APP_CONFIG[:illiad_base_url]
      illiad_params = get_illiad_params_explicit(bib_record, current_user)

      illiad_full_url = get_illiad_full_url(illiad_base_url, illiad_params)
      
      return illiad_full_url
    end


    private

    def get_illiad_full_url(illiad_base_url, illiad_params)
      illiad_url_with_params = illiad_base_url + '?' + illiad_params.to_query
      
      # Patrons always access Illiad through our CUL EZproxy
      # ezproxy_url = @service_config[:ezproxy_url]
      ezproxy_url = APP_CONFIG[:ezproxy_login_url]

      illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params
      
      return illiad_full_url
    end


    # Gather all of the params that we'll pass to be pre-filled into he ILLiad form.
    # "_explicit" meaning that Valet passes in values for Action and Form.
    # Versus passing in OpenURL args and letting ILLiad pick which Form to use.
    def get_illiad_params_explicit(bib_record, current_user)
      illiad_params = {}
      
      # ===> These params are the same for Books and Articles

      # Bib ID lands into hidden field "Notes" so patron cannot edit
      illiad_params['Notes']        = "http://clio.columbia.edu/catalog/#{bib_record.id}"

      # use "CitedIn" as a routing tag, so staff know the origin of the request
      illiad_params['CitedIn']      = 'CLIO_OPAC-DOCDEL'
      
      # Action=10 tells Illiad that we'll pass the Form ID to use
      illiad_params['Action']        = '10'

      # LIBSYS-5373 - add Patron Group / Active Barcode to Campus Scan
      illiad_params['ItemInfo2']     = current_user.barcode
      illiad_params['ItemInfo4']     = current_user.patron_groups.join(',')

      # illiad_params['sid']        = 'CLIO OPAC'   # I suspect this is no longer used?
      
      # ===> These params differ between Books and Articles
      if bib_record.issn.present?
        # If there's an ISSN, make an Article request (ArticleRequest.html)
        illiad_params['Form']        = '22'
        illiad_params.merge!(get_illiad_article_params(bib_record))
      else
        # Otherwise, make a Book Chapter request (BookChapterRequest.html)
        illiad_params['Form']        = '23'
        illiad_params.merge!(get_illiad_book_chapter_params(bib_record))
      end

      Oclc::Illiad.clean_hash_values(illiad_params)
      
      return illiad_params
    end

    
    def get_illiad_article_params(bib_record)
      article_params = {}
      
      article_params['PhotoJournalTitle']   = bib_record.title
      article_params['PhotoArticleAuthor']  = bib_record.author
      article_params['ISSN']                = bib_record.issn.first
      article_params['CallNumber']          = bib_record.call_number
      article_params['ESPNumber']           = bib_record.oclc_number

      return article_params
    end
    
      
    def get_illiad_book_chapter_params(bib_record)
      book_chapter_params = {}
      
      book_chapter_params['PhotoJournalTitle']  = bib_record.title
      book_chapter_params['PhotoItemAuthor']    = bib_record.author
      book_chapter_params['PhotoItemEdition']   = bib_record.edition
      book_chapter_params['PhotoItemPlace']     = bib_record.pub_place
      book_chapter_params['PhotoItemPublisher'] = bib_record.pub_name
      book_chapter_params['PhotoJournalYear']   = bib_record.pub_date
      book_chapter_params['ISSN']               = bib_record.isbn.first
      book_chapter_params['ESPNumber']          = bib_record.oclc_number
      
      return book_chapter_params
    end
      
      
  end
end

