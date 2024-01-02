
# These tests run against bibs with status 'precat'
# These 'precat' bibs become cataloged over time, and then
# we need to hunt down a new precat bib to test against.
# (Should be updated to use a fixture.)

RSpec.describe 'Precat Request Service' do
  it 'precat request renders form' do
    sign_in FactoryBot.create(:happyuser)
    get precat_path('6361088')
    expect(response.body).to include('Precataloging Item Request')
  end

  it 'precat form submission renders confirm and sends email' do
    user = FactoryBot.create(:happyuser)
    sign_in user
    params = { id: '6361088', note: 'testing' }
    post precat_index_path, params: params

    # confirm page
    expect(response.body).to include('Precataloging Retrieval Request Confirmation')

    # confirm email
    confirm_email = ActionMailer::Base.deliveries.last
    expect(confirm_email.from).to include(APP_CONFIG[:precat][:staff_email])
    expect(confirm_email.to).to include(APP_CONFIG[:precat][:staff_email])
    expect(confirm_email.to).to include(user[:email])
    expect(confirm_email.subject).to include('Precat Search Request')
    expect(confirm_email.body).to include('Precataloging Retrieval Request')
  end

  it 'rejects precat requests for non-precat items' do
    sign_in FactoryBot.create(:happyuser)
    get precat_path('123')
    expect(response.body).to include('item is not in Pre-Cataloging status')
  end

  it 'bounces unauth user to sign-in page' do
    get precat_path('123')
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existant item' do
    sign_in FactoryBot.create(:happyuser)
    # CLIO has no bib id 60
    get precat_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
