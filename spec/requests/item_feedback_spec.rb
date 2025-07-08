

RSpec.describe 'Item Feedback Service' do
  it 'item feedback renders form' do
    sign_in FactoryBot.create(:happyuser)
    get item_feedback_path('123')
    expect(response.body).to include('Item Feedback')
  end

  it 'item feedback form submission renders confirm and sends email' do
    user = FactoryBot.create(:happyuser)
    sign_in user
    params = { id: '123', mfhd_id: 'f8e01ca3-5d38-5f6a-89d0-cbe4c4716e89', feedback: 'other', note: 'testing' }
    post item_feedback_index_path, params: params

    # confirm page
    expect(response.body).to include('Item Feedback Confirmation')

    # confirm email
    confirm_email = ActionMailer::Base.deliveries.last
    expect(confirm_email.from).to include(APP_CONFIG[:precat][:staff_email])
    expect(confirm_email.to).to include(APP_CONFIG[:precat][:staff_email])
    expect(confirm_email.to).to include(user[:email])
    expect(confirm_email.subject).to include('Item Feedback')
    expect(confirm_email.body).to include('Item Feedback')
  end

  it 'rejects item feedback requests for non-Voyager items' do
    sign_in FactoryBot.create(:happyuser)
    get item_feedback_path('SCSB-1978013')
    expect(response.body).to include('item is not owned by Columbia')
  end

  it 'bounces unauth user to sign-in page' do
    get item_feedback_path('123')
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existant item' do
    sign_in FactoryBot.create(:happyuser)
    # CLIO has no bib id 60
    get item_feedback_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
