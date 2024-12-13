RSpec.describe 'FLI Paging' do

  it 'redirects SAC patron to ezproxy/illiad' do
    user = FactoryBot.create(:happyuser)
    user.affils = ['CUL_role-clio-SAC'] 
    sign_in user

    get fli_paging_path('2049141')

    illiad_params = [
      'Action=10',
      'CallNumber=E443+.H37+1997',
      'CitedIn=CLIO_OPAC-PAGING',
      'ESPNumber=36417797',
      'Form=20',
      'ISSN=9780195089837',
      'ItemInfo2=123456789',
      'ItemInfo4=SAC',
      'ItemNumber=',
      'LoanAuthor=Hartman%2C+Saidiya+V.',
      'LoanDate=1997.',
      'LoanEdition=',
      'LoanPlace=New+York',
      'LoanPublisher=Oxford+University+Press',
      'LoanTitle=Scenes+of+subjection+%3A+terror%2C+slavery%2C+and+self-making+in+nineteenth-century+America',
      'Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F2049141',
      'Value=GenericRequestPDD',
    ]

    illiad_url = 'https://ezproxy.cul.columbia.edu/login?url=' +
      'https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?' +
      illiad_params.join('&')

    expect(response).to redirect_to(illiad_url)

  end

  it 'redirects to REG patron to failure page' do
    sign_in FactoryBot.create(:happyuser)
    get fli_paging_path('123')
    expect(response).to redirect_to( APP_CONFIG[:fli_paging][:ineligible_url] )
  end


  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get fli_paging_path('123')
    expect(response).to redirect_to( APP_CONFIG[:fli_paging][:ineligible_url] )
  end

  it 'fails for non-FLI material' do
    user = FactoryBot.create(:happyuser)
    user.affils = ['CUL_role-clio-SAC'] 
    sign_in user
    get fli_paging_path('123')
    expect(response.body).to include('This record has no FLI Partnership holdings')
  end

end