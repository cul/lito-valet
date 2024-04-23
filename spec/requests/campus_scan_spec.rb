

RSpec.describe 'Campus Scan' do


  it 'presents campus-selection form' do
    sign_in FactoryBot.create(:happyuser)
    get campus_scan_path('123')
    expect(response.body).to include('Please select your campus')
  end


  it 'redirects MBUTS-campus patrons to ezproxy/illiad (book chapter)' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'mbuts' }
    post campus_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CitedIn=CLIO_OPAC-DOCDEL&ESPNumber=3777209&Form=23&ISSN=&ItemInfo2=123456789&ItemInfo4=REG&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F123&PhotoItemAuthor=Sokorski%2C+W%C5%82odzimierz&PhotoItemEdition=Wyd.+1.&PhotoItemPlace=Warszawa&PhotoItemPublisher=Pan%CC%81stwowy+Instytut+Wydawniczy&PhotoJournalTitle=Piotr&PhotoJournalYear=1976.')
  end

  it 'redirects MBUTS-campus patrons to ezproxy/illiad (article)' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '101', campus: 'mbuts' }
    post campus_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CallNumber=Z732.V5+V55&CitedIn=CLIO_OPAC-DOCDEL&ESPNumber=2172527&Form=22&ISSN=0363-3500&ItemInfo2=123456789&ItemInfo4=REG&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F101&PhotoArticleAuthor=Vermont.+Department+of+Libraries&PhotoJournalTitle=Biennial+report+of+the+Vermont+Department+of+Libraries')
  end

  it 'redirects MCC-campus patrons to ezproxy/illiad' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'mcc' }
    post campus_scan_index_path, params: params

    expect(response).to redirect_to('https://ezproxy.cul.columbia.edu/login?url=https://columbia.illiad.oclc.org/illiad/zcu/illiad.dll?Action=10&CitedIn=CLIO_OPAC-DOCDEL&ESPNumber=3777209&Form=23&ISSN=&ItemInfo2=123456789&ItemInfo4=REG&Notes=http%3A%2F%2Fclio.columbia.edu%2Fcatalog%2F123&PhotoItemAuthor=Sokorski%2C+W%C5%82odzimierz&PhotoItemEdition=Wyd.+1.&PhotoItemPlace=Warszawa&PhotoItemPublisher=Pan%CC%81stwowy+Instytut+Wydawniczy&PhotoJournalTitle=Piotr&PhotoJournalYear=1976.')
  end

  it 'redirects TC-campus patrons to TC website' do
    sign_in FactoryBot.create(:happyuser)

    params = { id: '123', campus: 'tc' }
    post campus_scan_index_path, params: params

    # expect(response).to redirect_to('https://library.tc.columbia.edu/p/request-materials')
    expect(response).to redirect_to('https://library.tc.columbia.edu/services')
  end

  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get campus_scan_path('123')
    expect(response).to redirect_to( APP_CONFIG[:campus_scan][:ineligible_url] )
  end


end



