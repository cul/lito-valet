# Common logic for interacting with the OCLC ILLiad system
module Oclc
  class Illiad
    # These parameters should be included with any ILLiad request
    def self.get_default_params(current_user, bib_record = nil)
      params = {}

      # If we were called from a service that worked upon a bib record, then
      # Bib ID lands into hidden field "Notes" so patron cannot edit
      if bib_record.present?
        params['Notes'] = "http://clio.columbia.edu/catalog/#{bib_record.id}"
      end

      # LIBSYS-3206 - add Patron Group / Active Barcode
      # LIBSYS-5293 - add Patron Group / Active Barcode to ILL (cf. LIBSYS-3206)
      # LIBSYS-5373 - add Patron Group / Active Barcode to Campus Scan
      params['ItemInfo2'] = current_user.barcode
      params['ItemInfo4'] = current_user.patron_groups.join(',')

      # # LIBSYS-7889 - Try using UserInfo fields - awaiting testing
      # params['UserInfo3'] = current_user.barcode
      # params['UserInfo2'] = current_user.patron_groups.join(',')

      return params
    end

    # Params used for various Paging requests
    def self.get_paging_params(bib_record)
      params = {}

      # Basic params to pass along bibliographic details
      # Illiad param keys need to match the Illiad form field names
      params['LoanTitle']     = bib_record.title
      params['LoanAuthor']    = bib_record.author
      params['ISSN']          = bib_record.isbn.first
      params['CallNumber']    = bib_record.call_number
      params['ESPNumber']     = bib_record.oclc_number
      params['ItemNumber']    = (bib_record.barcodes.size == 1 ? bib_record.barcodes.first : '')
      params['LoanEdition']   = bib_record.edition
      params['LoanPlace']     = bib_record.pub_place
      params['LoanPublisher'] = bib_record.pub_name
      params['LoanDate']      = bib_record.pub_date

      return params
    end

    # Article-specific params used for various Scan requests
    def self.get_article_params(bib_record)
      article_params = {}

      article_params['PhotoJournalTitle']   = bib_record.title
      article_params['PhotoArticleAuthor']  = bib_record.author
      article_params['ISSN']                = bib_record.issn.first
      article_params['CallNumber']          = bib_record.call_number
      article_params['ESPNumber']           = bib_record.oclc_number

      return article_params
    end

    # Book-Chapter-specific params used for various Scan requests
    def self.get_book_chapter_params(bib_record)
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

    # LIBSYS-3273 - some special characters choke ILLiad.
    # I can't get escaping to work, so just remove them.
    def self.clean_hash_values(hash)
      hash.each do |key, value|
        next unless key && value

        # strip problematic angle-bracket chars from the value
        value.gsub!(/\>/, '')
        value.gsub!(/\</, '')
        # other chars that shouldn't be in bib fields
        value.gsub!(/\&/, '')
        value.gsub!(/\%/, '')
        value.gsub!(/\#/, '')
      end
      return hash
    end

    def self.build_full_url(illiad_url, illiad_params)
      illiad_url_with_params = illiad_url + '?' + illiad_params.to_query

      # Patrons always access Illiad through our CUL EZproxy
      ezproxy_url = APP_CONFIG[:ezproxy_login_url]

      illiad_full_url = ezproxy_url + '?url=' + illiad_url_with_params

      return illiad_full_url
    end
  end
end
