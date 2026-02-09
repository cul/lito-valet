RSpec.describe 'ILL Scan' do
  it 'presents campus-selection form' do
    sign_in FactoryBot.create(:happyuser)
    get ill_scan_path('123')
    expect(response.body).to include('Please select your campus')
  end

  it 'redirects MBUTS-campus patrons to ezproxy/illiad (book chapter)' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'mbuts' }
    post ill_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CitedIn=CLIO_OPAC-ILL&ESPNumber=3777209&Form=23&ISSN=&ItemInfo2=123456789&ItemInfo4=Undergraduate&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F123&PhotoItemAuthor=Sokorski%2C+W%C5%82odzimierz&PhotoItemEdition=Wyd.+1.&PhotoItemPlace=Warszawa&PhotoItemPublisher=Pa%C5%84stwowy+Instytut+Wydawniczy&PhotoJournalTitle=Piotr&PhotoJournalYear=1976.')
  end

  it 'redirects MBUTS-campus patrons to ezproxy/illiad (article)' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '101', campus: 'mbuts' }
    post ill_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CallNumber=Z732.V5+V55&CitedIn=CLIO_OPAC-ILL&ESPNumber=2172527&Form=22&ISSN=0363-3500&ItemInfo2=123456789&ItemInfo4=Undergraduate&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F101&PhotoArticleAuthor=Vermont.+Department+of+Libraries&PhotoJournalTitle=Biennial+report+of+the+Vermont+Department+of+Libraries')
  end

  it 'redirects MCC-campus patrons to ezproxy/illiad' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'mcc' }
    post ill_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CitedIn=CLIO_OPAC-ILL&ESPNumber=3777209&Form=23&ISSN=&ItemInfo2=123456789&ItemInfo4=Undergraduate&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F123&PhotoItemAuthor=Sokorski%2C+W%C5%82odzimierz&PhotoItemEdition=Wyd.+1.&PhotoItemPlace=Warszawa&PhotoItemPublisher=Pa%C5%84stwowy+Instytut+Wydawniczy&PhotoJournalTitle=Piotr&PhotoJournalYear=1976.')
  end

  it 'redirects TC-campus patrons to TC ILL Request form' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'tc' }
    post ill_scan_index_path, params: params

    # expect(response).to redirect_to('https://library.tc.columbia.edu/p/request-materials')
    expect(response).to redirect_to('https://resolver.library.columbia.edu/tc-ill')
  end

  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get ill_scan_path('123')
    expect(response).to redirect_to(APP_CONFIG[:ill_scan][:ineligible_url])
  end
end
