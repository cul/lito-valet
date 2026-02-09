RSpec.describe 'Campus Paging' do
  it 'redirects to ezproxy/illiad' do
    sign_in FactoryBot.create(:happyuser)
    get campus_paging_path('123')

    illiad_params = [
      'Action=10',
      'CallNumber=PG7178.O45+P5',
      'CitedIn=CLIO_OPAC-PAGING',
      'ESPNumber=3777209',
      'Form=20',
      'ISSN=',
      'ItemInfo2=123456789',
      'ItemInfo4=Undergraduate',
      'ItemNumber=0109179160',
      'LoanAuthor=Sokorski%2C+W%C5%82odzimierz',
      'LoanDate=1976.',
      'LoanEdition=Wyd.+1.',
      'LoanPlace=Warszawa',
      'LoanPublisher=Pa%C5%84stwowy+Instytut+Wydawniczy',
      'LoanTitle=Piotr',
      'Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F123',
      'Value=GenericRequestPDD'
    ]

    illiad_url = 'https://ezproxy.cul.columbia.edu/login?url=' +
                 'https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?' +
                 illiad_params.join('&')

    expect(response).to redirect_to(illiad_url)
  end

  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get campus_paging_path('123')
    expect(response).to redirect_to(APP_CONFIG[:campus_paging][:ineligible_url])
  end
end
