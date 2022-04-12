
RSpec.describe 'ReCAP Loan' do
  
  
  it 'presents item-selection and delivery-location form' do
    sign_in FactoryBot.create(:happyuser)
    get recap_loan_path('3269684', '3791843')

    # Item Selection
    expect(response.body).to include( 'Please select one or more items' )
    # Specific barcodes should be listed
    expect(response.body).to include( 'CU02281112' )
    expect(response.body).to include( 'CU02281120' )
 
    # Delivery Location
    expect(response.body).to include( 'Please select campus pick-up location' )
    # - specific delivery locations in drop-down menu
    expect(response.body).to include( 'Butler Library' )
    expect(response.body).to include( 'Health Sciences Library' )
  end
  
  
  it 'non-offsite bib gives error message' do
    sign_in FactoryBot.create(:happyuser)
    get recap_loan_path('123', '144')
    expect(response.body).to include( 'Bib ID 123 is not eligble for service Offsite Pick-Up' )
  end


  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get recap_loan_path('101', '118')
    expect(response).to redirect_to( APP_CONFIG[:recap_loan][:ineligible_url] )
  end

  it 'restricts campus-delivery location by customer code for Princeton QK' do
    sign_in FactoryBot.create(:happyuser)

    # Princeton QK customer code: SCSB-1855010
    get recap_loan_path('SCSB-1855010', '1830621')
    # - specific delivery location as only option in drop-down menu
    music_only = '<select name="deliveryLocation" id="deliveryLocation" class="retrieval-field"><option selected="selected" value="MR">Music &amp; Arts Library</option></select>'
    expect(response.body).to include( music_only )
  end

  it 'restricts campus-delivery location by customer code for Harvard FL' do
    sign_in FactoryBot.create(:happyuser)

    # Harvard FL customer code: SCSB-10471305, SCSB-10058654, SCSB-10485093
    get recap_loan_path('SCSB-10471305')
    # - specific delivery location as only option in drop-down menu
    avery_only = '<select name="deliveryLocation" id="deliveryLocation" class="retrieval-field"><option selected="selected" value="AR">Avery Library</option></select>'
    expect(response.body).to include( avery_only )
  end

  it 'restricts campus-delivery location by customer code for Princeton PJ' do
    sign_in FactoryBot.create(:happyuser)

    # Harvard PJ customer code: SCSB-1823394
    get recap_loan_path('SCSB-1823394')
    # - specific delivery location as only option in drop-down menu
    avery_only = '<select name="deliveryLocation" id="deliveryLocation" class="retrieval-field"><option selected="selected" value="AR">Avery Library</option></select>'
    expect(response.body).to include( avery_only )
  end

end


