RSpec.describe 'Campus Paging' do

  it 'redirects to ezproxy/illiad' do
    sign_in FactoryBot.create(:happyuser)
    get campus_paging_path('123')
    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CallNumber=PG7178.O45+P5&CitedIn=CLIO_OPAC-PAGING&ESPNumber=3777209&Form=20&ISSN=&ItemNumber=0109179160&LoanAuthor=Sokorski%2C+W%C5%82odzimierz&LoanDate=1976.&LoanEdition=Wyd.+1.&LoanPlace=Warszawa&LoanPublisher=Pan%CC%81stwowy+Instytut+Wydawniczy&LoanTitle=Piotr&Value=GenericRequestPDD')
    # expect(response.body).to include('BearStor Request')
  end


  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get campus_paging_path('123')
    expect(response).to redirect_to( APP_CONFIG[:campus_paging][:ineligible_url] )
  end

end

