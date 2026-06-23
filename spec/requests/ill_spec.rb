# spec/requests/ill_spec.rb
#
# ILL is a two-step service:
# Step 1: GET /ill  - shows campus-selection form (or redirects TC patrons)
# Step 2: POST /ill - processes campus choice, redirects to ILLiad

RSpec.describe 'ILL' do

  it 'bounces unauthenticated user to sign-in page' do
    get '/ill'
    expect(response).to redirect_to('http://www.example.com/sign_in')
  end

  it 'redirects ineligible user to ineligible URL' do
    sign_in FactoryBot.create(:blockeduser)
    get '/ill'
    expect(response).to redirect_to(APP_CONFIG[:ill][:ineligible_url])
  end

  # Step 1: GET with no params - shows campus-selection form
  it 'renders campus-selection form' do
    sign_in FactoryBot.create(:happyuser)
    get '/ill'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('campus')
  end

  # Step 2a: POST with campus=tc - redirect to TC ILL page
  it 'redirects TC campus patrons to TC ILL page' do
    sign_in FactoryBot.create(:happyuser)
    post ill_index_path, params: { campus: 'tc' }
    expect(response).to redirect_to('https://resolver.library.columbia.edu/tc-ill')
  end

  # Step 2b: POST with campus=MBUTS and no bib - redirect to ILLiad login
  it 'with no bib ID, redirects to ILLiad login page' do
    sign_in FactoryBot.create(:happyuser)
    post ill_index_path, params: { campus: 'MBUTS' }
    expect(response).to redirect_to(APP_CONFIG[:illiad_login_url])
  end

  # Step 2c: POST with campus=MCC and no bib - redirect to ZCH ILLiad
  it 'redirects MCC campus patrons to Health Sciences ILLiad' do
    sign_in FactoryBot.create(:happyuser)
    post ill_index_path, params: { campus: 'mcc' }
    expect(response).to redirect_to(APP_CONFIG[:illiad_login_url_zch])
  end

  # # Not yet implemented
  # # Step 2d: POST with campus and bib ID - builds OpenURL and redirects
  # it 'with bib ID and campus, redirects to ILLiad OpenURL' do
  #   sign_in FactoryBot.create(:happyuser)
  #   post ill_index_path, params: { campus: 'MBUTS', id: '9041682' }
  #   expect(response).to redirect_to(/columbia\.illiad\.oclc\.org/)
  #   expect(response.location).to include('OpenURL')
  # end
end
