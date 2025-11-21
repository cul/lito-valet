module Service
  class Notonshelf < Service::Base

    def setup_form_locals(params, bib_record, current_user)
      sorted_holdings = bib_record.holdings.sort_by { |h| h[:location_display].to_s }
      availability ||= bib_record.fetch_folio_availability
      
      locals = {
        bib_record: bib_record,
        holdings: sorted_holdings
      }
      locals
    end

    # params looks like this:
    # {"id"=>"5685777", "mfhd_id"=>"88596060-5a76-5255-9999-0ff9b88aa112", "note"=>"test"}
    def send_emails(params, bib_record, current_user)
      
      # which holding (location) has the missing book?
      holding = bib_record.holdings.select { |h| h[:mfhd_id] == params['mfhd_id'] }.first
      
      mail_params = {
        bib_record: bib_record,
        patron_uni: current_user.uid,
        patron_email: current_user.email,
        location_display: holding[:location_display],
        location_code: holding[:location_code],
        staff_email: get_email_alias_for_location( holding[:location_code] ),
        note: params['note']
      }
      # mail request to staff_email:
      FormMailer.with(mail_params).notonshelf_request.deliver_now
    end

    # The confirmation web page shows the same data as the email?
    def get_confirmation_locals(params, bib_record, current_user)

      # which holding (location) has the missing book?
      holding = bib_record.holdings.select { |h| h[:mfhd_id] == params['mfhd_id'] }.first

      confirm_locals = {
        bib_record: bib_record,
        patron_uni: current_user.uid,
        patron_email: current_user.email,
        location_display: holding[:location_display],
        location_code: holding[:location_code],
        staff_email: get_email_alias_for_location( holding[:location_code] ),
        note: params['note']
      }
      confirm_locals
    end



    def get_email_alias_for_location(location_code)
      rules = {
        /^bar,mil/ => "butler_circulation@libraries.cul.columbia.edu",

        /^(bwc|bar|bdc|bdg)/ =>
          "barnard_circulation@libraries.cul.columbia.edu",

        /^ref/ =>
          "reference_circulation@libraries.cul.columbia.edu",

        /^(asx|docs|dsc|leh|les|lsp|lsw|map|off,docs|off,les)/ =>
          "lehman_circulation@libraries.cul.columbia.edu",

        /^bio/ =>
          "biology_circulation@libraries.cul.columbia.edu",

        /^(bsc|bsr|bus)/ =>
          "business_circulation@libraries.cul.columbia.edu",

        /^che/ =>
          "chemistry_circulation@libraries.cul.columbia.edu",

        /^(clm|dic|gax|off,dic|off,oral|off,rbms|off,rbx|off,uacl|oral|rbx|rbi|rbms|uacl)/ =>
          "butler_circulation@libraries.cul.columbia.edu",

        /^(eal|ean|ear|eax|off,eal|off,ean|off,ear|off,eax)/ =>
          "starr_east_asian_circulation@libraries.cul.columbia.edu",

        /^(jazz|msa|msc|msci|msr|mus|mvr|off,msc|off,msr|off,mus|off,mvr)/ =>
          "music_circulation@libraries.cul.columbia.edu",

        /^(for,morn|hmc|hml|hsl|nyspi|hsx|off,hsar|off,hsl|off,hsr|off,hssc|orth)/ =>
          "health_sciences_circulation@libraries.cul.columbia.edu",

        /^(off,uta|off,utmrl|off,utn|off,utp|off,uts|uts)/ =>
          "uts_circulation@libraries.cul.columbia.edu",

        /^psy/ =>
          "psychology_circulation@libraries.cul.columbia.edu",

        /^phy,/ =>
          "mathsci@libraries.cul.columbia.edu",

        /^phy/ =>
          "physics_circulation@libraries.cul.columbia.edu",

        /^swx/ =>
          "social_work_circulation@libraries.cul.columbia.edu",

        /^mat/ =>
          "math_science_circulation@libraries.cul.columbia.edu",

        /^sci/ =>
          "scieng_circulation@libraries.cul.columbia.edu",

        /^jou/ =>
          "journalism_circulation@libraries.cul.columbia.edu",

        /^(ewng|gsc|off,gsc)/ =>
          "geoscience_circulation@libraries.cul.columbia.edu",

        /^(off,glg|glg)/ =>
          "geology_circulation@libraries.cul.columbia.edu",

        /^eng/ =>
          "engineering_circulation@libraries.cul.columbia.edu",

        /^(ava|avda|ave|avr|faa|far|fax|off,avda|off,avr|off,far|off,fax|off,war|war)/ =>
          "avery_circulation@libraries.cul.columbia.edu"
      }

      rules.each do |regex, email_alias|
        return email_alias if location_code =~ regex
      end

      # Default:
      "butler_circulation@libraries.cul.columbia.edu"
    end





  end
end
