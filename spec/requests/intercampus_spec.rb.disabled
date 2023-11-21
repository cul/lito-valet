

RSpec.describe 'Intercampus Request Service' do
  it 'redirects to resolver link' do
    get intercampus_path('123')
    bounce_url = APP_CONFIG[:intercampus][:bounce_url]
    expect(response).to redirect_to(bounce_url)
  end

  it 'rejects off-site columbia records' do
    get intercampus_path('528008')
    expect(response.body).to include('item has no on-campus holdings')
  end

  it 'rejects ReCAP partner records' do
    get intercampus_path('SCSB-1441991')
    expect(response.body).to include('not a Columbia item')
  end

  it 'renders error page for non-existant item' do
    # CLIO has no bib id 60
    get intercampus_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
