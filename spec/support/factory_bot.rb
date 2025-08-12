

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

FactoryBot.define do

  # regular good user (good affils)
  factory :happyuser, class: User do
    uid { 'jdoe' }
    first_name { 'John' }
    last_name  { 'Doe' }
    email { 'jdoe@columbia.edu' }
    barcode { '123456789' }
    affils { ['LIB_clio-Undergraduate'] }

    # The same user - but now blocked
    factory :blockeduser do
      affils { ['CUL_role-clio-REG-blocked'] }
    end

    # FOLIO - stop relying on Voyager ILS patron record
    # # Valet should not directly test these values anymore,
    # # but the "offsite" path still does, and we still need
    # # that for bound-with support.
    # patron_record {{
    #   "INSTITUTION_ID"=>"jdoe",
    #   "PATRON_ID"=>123,
    #   "EXPIRE_DATE"=>'2050-01-01 01:01:01 -0500',
    #   "TOTAL_FEES_DUE"=>0
    # }}

    # patron_barcode_record {{
    #   "PATRON_BARCODE"=>"123456789",
    #   "BARCODE_STATUS"=>1
    # }}
    # over_recall_notice_count { 0 }

    # factory :expireduser do
    #   patron_record {{
    #     "INSTITUTION_ID"=>"jdoe",
    #     "PATRON_ID"=>123,
    #     "EXPIRE_DATE"=>'2000-01-01 01:01:01 -0500',
    #     "TOTAL_FEES_DUE"=>0
    #   }}
    # end
    #
    # factory :blockeduser do
    #   patron_record {{
    #     "INSTITUTION_ID"=>"jdoe",
    #     "PATRON_ID"=>123,
    #     "EXPIRE_DATE"=>'2050-01-01 01:01:01 -0500',
    #     "TOTAL_FEES_DUE"=>99999
    #   }}
    # end
    #
    # factory :recalleduser do
    #   over_recall_notice_count { 99 }
    # end

  end

end
