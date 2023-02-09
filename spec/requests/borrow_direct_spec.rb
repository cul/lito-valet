

RSpec.describe 'Borrow Direct' do

  # Some constants used throughout this file
  reshare_base_url   = 'https://columbia-borrowdirect.reshare.indexdata.com'
  reshare_search_url = reshare_base_url + '/Search/Results'


  it 'redirects to ReShare with ISBN' do
    sign_in FactoryBot.create(:happyuser)

    # hardcode expected URL
    reshare_url = reshare_search_url + '?type=ISN&lookfor=9780374275631'

    get borrow_direct_path('9041682')
    expect(response).to redirect_to(reshare_url)
  end

  it 'redirects to ReShare with ISSN' do
    sign_in FactoryBot.create(:happyuser)

    # hardcode expected URL
    reshare_url = reshare_search_url + '?type=ISN&lookfor=0070-4717'

    get borrow_direct_path('4485990')
    expect(response).to redirect_to(reshare_url)
  end

  it 'redirects to ReShare with title/author' do
    sign_in FactoryBot.create(:happyuser)

    # hardcode expected URL
    reshare_url = reshare_search_url + 
                  '?type0[]=Title&lookfor0[]="Piotr"' \
                  '&type0[]=Author&lookfor0[]="Sokorski%2C+W%C5%82odzimierz"' \
                  '&join=AND'

    get borrow_direct_path('123')
    expect(response).to redirect_to(reshare_url)
  end

  it 'redirects to ReShare for SCSB ReCAP Partner item' do
    sign_in FactoryBot.create(:happyuser)

    # hardcode expected URL
    reshare_url = reshare_search_url + 
                 '?type0[]=Title&lookfor0[]="A+national+public+labor+relations+policy+for+tomorrow"' \
                 '&type0[]=Author&lookfor0[]="Emery%2C+James+A."' \
                 '&join=AND'

    get borrow_direct_path('SCSB-1441991')
    expect(response).to redirect_to(reshare_url)
  end

  it 'bounces unauth user to sign-in page' do
    get borrow_direct_path('123')
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existant item' do
    sign_in FactoryBot.create(:happyuser)
    # CLIO has no bib id 60
    get borrow_direct_path('60')
    expect(response.body).to include('Cannot find bib record')
  end

  it 'redirects blocked patron to failure page' do
    sign_in FactoryBot.create(:blockeduser)
    get borrow_direct_path('123')
    ineligible_url = APP_CONFIG[:borrow_direct][:ineligible_url]
    
    expect(response).to redirect_to(ineligible_url)
  end
  
  # Valet's Borrow Direct also 
  
  it 'without bib id, redirects authorized users to ILLiad' do
    sign_in FactoryBot.create(:happyuser)

    # For ReShare, the non-search URL is just the base URL
    reshare_url = reshare_base_url
    
    get '/borrow_direct'
    expect(response).to redirect_to(reshare_url)
  end

  it 'without bib id, redirects unauthorized users to ineligible URL' do
    sign_in FactoryBot.create(:blockeduser)

    ineligible_url = APP_CONFIG[:borrow_direct][:ineligible_url]
  
    get '/borrow_direct'
    expect(response).to redirect_to(ineligible_url)
  end
    

  # Valet no longer checks patron conditions directly.
  # Valet goes by the LDAP Affils only.
  #
  # # Various invalid-patron conditions....
  #
  # # it 'user without patron record - redirects to INELIGIBLE_URL' do
  # #   sign_in FactoryBot.create(:happyuser, patron_record: nil)
  # #   get borrow_direct_path('123')
  # #   expect(response).to redirect_to(INELIGIBLE_URL)
  # # end
  #
  # # it 'expired user - redirects to INELIGIBLE_URL' do
  # #   sign_in FactoryBot.create(:expireduser)
  # #   get borrow_direct_path('123')
  # #   expect(response).to redirect_to(INELIGIBLE_URL)
  # # end
  #
  # # it 'blocked user - redirects to INELIGIBLE_URL' do
  # #   sign_in FactoryBot.create(:blockeduser)
  # #   get borrow_direct_path('123')
  # #   expect(response).to redirect_to(INELIGIBLE_URL)
  # # end
  #
  # # it 'user with recalls - redirects to INELIGIBLE_URL' do
  # #   sign_in FactoryBot.create(:recalleduser)
  # #   get borrow_direct_path('123')
  # #   expect(response).to redirect_to(INELIGIBLE_URL)
  # # end
  # #
  # # it 'user with good patron group - succeeds' do
  # #   good_url = 'https://bd.relaisd2d.com/?' \
  # #              'LS=COLUMBIA&PI=123456789&' \
  # #              'query=isbn%3D9780374275631'
  # #   good_groups = ['GRD','OFF','REG','SAC']
  # #   sign_in FactoryBot.create(:happyuser, patron_group: good_groups.sample)
  # #   get borrow_direct_path('9041682')
  # #   expect(response).to redirect_to(good_url)
  # # end
  # #
  # #
  # # it 'user with bad patron group - redirects to INELIGIBLE_URL' do
  # #   sign_in FactoryBot.create(:happyuser, patron_group: 'BAD')
  # #   get borrow_direct_path('123')
  # #   expect(response).to redirect_to(INELIGIBLE_URL)
  # # end
  # #
  # # it '2CUL user with bad patron group  - succeeds' do
  # #   good_url = 'https://bd.relaisd2d.com/?' \
  # #              'LS=COLUMBIA&PI=123456789&' \
  # #              'query=isbn%3D9780374275631'
  # #   sign_in FactoryBot.create(:happyuser, patron_group: 'BAD', patron_stats: ['2CU'])
  # #   get borrow_direct_path('9041682')
  # #   expect(response).to redirect_to(good_url)
  # # end

end
