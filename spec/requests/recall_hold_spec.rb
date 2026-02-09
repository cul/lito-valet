RSpec.describe 'Recall / Hold Request Service' do
  # it 'redirects anonymous user to Voyager URL for Voyager item' do
  #   bib = '123'
  #   get recall_hold_path(bib)
  #   voyager_url = APP_CONFIG[:recall_hold][:voyager_url] + bib
  #   expect(response).to redirect_to(voyager_url)
  # end
  #
  # it 'redirects authenticated user to Voyager URL for Voyager item' do
  #   sign_in FactoryBot.create(:happyuser)
  #   bib = '123'
  #   get recall_hold_path(bib)
  #   voyager_url = APP_CONFIG[:recall_hold][:voyager_url] + bib
  #   expect(response).to redirect_to(voyager_url)
  # end
  #
  # it 'renders error page for non-existant item' do
  #   # CLIO has no bib id 60
  #   get recall_hold_url('60')
  #   expect(response.body).to include('No bib record found')
  # end
  #
  # it 'renders error page for law item' do
  #   get recall_hold_url('b228777')
  #   expect(response.body).to include('not owned by Columbia')
  # end
  #
  # it 'renders error page for ReCAP Partner item' do
  #   get recall_hold_url('SCSB-1441991')
  #   expect(response.body).to include('not owned by Columbia')
  # end
end
