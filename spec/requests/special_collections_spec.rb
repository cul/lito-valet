# spec/requests/special_collections_spec.rb
#
# Special Collections has no :authenticate requirement - all users including
# unauthenticated can access the service (external researchers are permitted).
#
# Path helpers:
#   GET  /special_collections/:id  ->  special_collection_path(id)  (show)
#   POST /special_collections      ->  special_collections_path     (create)
#
# Bib notes (verified against test Solr):
#   60        - does not exist (error case)
#   123       - exists but has no SC holdings (ineligible)
#   9020294   - rbms, 2 holdings, no items -> holding-level containers, renders form
#   13262502  - rbms, 1 holding, no items  -> single holding-level container, bounces to Aeon
#   2268048   - rbx,  multiple item-level containers, renders form
#   10161745  - rbx,  single item-level container, bounces to Aeon
#
# Finding aid bounce path: no bib currently available in test Solr with a findingaids.
# library.columbia.edu 856 link - add a test here when one is identified.

RSpec.describe 'Special Collections' do

  # --- Error cases ---

  it 'renders error for non-existent bib' do
    get special_collection_path('60')
    expect(response.body).to include('Cannot find bib record')
  end

  it 'rejects bib with no special collections holdings' do
    get special_collection_path('123')
    expect(response.body).to include('no holdings in any Special Collections library')
  end

  # --- Item-level containers (rbx holdings with items) ---

  it 'renders container-selection form for bib with multiple item-level containers' do
    sign_in FactoryBot.create(:happyuser)
    get special_collection_path('2268048')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Special Collections')
  end

  it 'bounces directly to Aeon for bib with single item-level container' do
    sign_in FactoryBot.create(:happyuser)
    get special_collection_path('10161745')
    expect(response).to redirect_to(/aeon\.cul\.columbia\.edu/)
    expect(response.location).to include('ReferenceNumber=10161745')
    expect(response.location).to include('Site=RBMLCUL')
  end

  # --- Holding-level containers (rbms holdings - no items, request_entire_holding) ---

  it 'renders container-selection form for rbms bib with multiple holding-level containers' do
    sign_in FactoryBot.create(:happyuser)
    get special_collection_path('9020294')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('BAR Ms Coll Gornyi')
  end

  it 'bounces directly to Aeon for rbms bib with single holding-level container' do
    sign_in FactoryBot.create(:happyuser)
    get special_collection_path('13262502')
    expect(response).to redirect_to(/aeon\.cul\.columbia\.edu/)
    expect(response.location).to include('ReferenceNumber=13262502')
    expect(response.location).to include('Site=RBMLCUL')
  end

  # --- Form submission ---

  it 'form submission with item container_id redirects to Aeon' do
    sign_in FactoryBot.create(:happyuser)
    bib_record = ClioRecord.new_from_bib_id('2268048')
    service = Service::SpecialCollections.new(APP_CONFIG[:special_collections])
    container_id = service.get_container_list(bib_record).first[:container_id]
    post special_collections_path, params: { id: '2268048', container_id: container_id }
    expect(response).to redirect_to(/aeon\.cul\.columbia\.edu/)
    expect(response.location).to include('ReferenceNumber=2268048')
  end

  it 'form submission with holding container_id redirects to Aeon' do
    sign_in FactoryBot.create(:happyuser)
    bib_record = ClioRecord.new_from_bib_id('9020294')
    service = Service::SpecialCollections.new(APP_CONFIG[:special_collections])
    container_id = service.get_container_list(bib_record).first[:container_id]
    post special_collections_path, params: { id: '9020294', container_id: container_id }
    expect(response).to redirect_to(/aeon\.cul\.columbia\.edu/)
    expect(response.location).to include('ReferenceNumber=9020294')
    expect(response.location).to include('Site=RBMLCUL')
  end

  # --- Finding aid bounce (no suitable test bib currently in test Solr) ---
  # it 'redirects to finding aid when one exists' do
  #   get special_collection_path('FINDING_AID_BIB_ID')
  #   expect(response).to redirect_to(/findingaids\.library\.columbia\.edu/)
  # end

end
