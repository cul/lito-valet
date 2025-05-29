

RSpec.describe 'Offsite Request Service' do
  it 'bounces unauth user to sign-in page' do
    get offsite_requests_path
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'asks for bib if none given' do
    sign_in FactoryBot.create(:happyuser)

    get offsite_requests_path
    expect(response).to redirect_to(bib_offsite_requests_path)
  end

  it 'rejects bib with no offsite holdings' do
    sign_in FactoryBot.create(:happyuser)

    get holding_offsite_requests_path, params: { bib_id: '123' }
    expect(request.flash[:error]).to include('has no offsite holdings')
    expect(response).to redirect_to(bib_offsite_requests_path)
  end

  it 'redirects multi-holding bib to holding-selection' do
    sign_in FactoryBot.create(:happyuser)

    params = { bib_id: '1958690' }
    get bib_offsite_requests_path, params: params
    expect(response).to redirect_to(holding_offsite_requests_path(params: params))
  end

  it 'holding-selection form renders correctly' do
    sign_in FactoryBot.create(:happyuser)

    get holding_offsite_requests_path, params: { bib_id: '1958690' }
    expect(response.body).to include('Which holding of this record would you like')
  end

  it 'redirects single-holding bib to new request path' do
    sign_in FactoryBot.create(:happyuser)

    params = { bib_id: '5396605' }
    get holding_offsite_requests_path, params: params
    params = { bib_id: '5396605', mfhd_id: '2dc5acf7-4f48-54e5-96ad-df08990db387' }
    expect(response).to redirect_to(new_offsite_request_path(params: params))
  end

  it 'renders item-request form correctly' do
    sign_in FactoryBot.create(:happyuser)

    params = { bib_id: '5396605', mfhd_id: '2dc5acf7-4f48-54e5-96ad-df08990db387' }
    get new_offsite_request_path, params: params
    expect(response.body).to include('Please select one or more items')
    expect(response.body).to include('Item to Library')
    expect(response.body).to include('Citation') # EDD includes Citation form
  end

  it 'blocked users get item-request form with "suspension" message' do
    affils =  ['CUL_role-clio-REG', 'CUL_role-clio-REG-blocked'] 
    sign_in FactoryBot.create(:happyuser, affils: affils)

    params = { bib_id: '5396605', mfhd_id: '2dc5acf7-4f48-54e5-96ad-df08990db387' }
    get new_offsite_request_path, params: params
    expect(response.body).to include('Please select one or more items')
    expect(response.body).to include('Item to Library')
    expect(response.body).not_to include('Citation') # EDD includes Citation form
    expect(response.body).to include('suspension of borrowing privileges')
  end

  # it 'RECAP patron group users get item-request form without EDD option' do
  #   sign_in FactoryBot.create(:happyuser, patron_group: 'RECAP')
  #
  #   params = { bib_id: '5396605', mfhd_id: '6224583' }
  #   get new_offsite_request_path, params: params
  #   expect(response.body).to include('Please select one or more items')
  #   expect(response.body).to include('Item to Library')
  #   # LIBSYS-1936 - prohibit EDD to patron-group RECAP
  #   expect(response.body).not_to include('Citation') # EDD includes Citation form
  #   expect(response.body).to include('not eligible to make EDD requests')
  #   expect(response.body).not_to include('suspension of borrowing privileges')
  # end

end
