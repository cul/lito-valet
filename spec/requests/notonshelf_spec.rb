# spec/requests/notonshelf_spec.rb

RSpec.describe 'Not On Shelf' do
  # 123 is a known good bib with holdings
  it 'renders the not-on-shelf form' do
    sign_in FactoryBot.create(:happyuser)
    get notonshelf_path('123')
    expect(response.body).to include('Not On Shelf')
    expect(response.body).not_to include('error')
  end

  it 'bounces unauthenticated user to sign-in page' do
    get notonshelf_path('123')
    expect(response).to redirect_to('http://www.example.com/sign_in')
  end

  it 'form submission renders confirm page and sends staff email' do
    user = FactoryBot.create(:happyuser)
    sign_in user

    params = { id: '123', mfhd_id: ClioRecord.new_from_bib_id('123').holdings.first[:mfhd_id], note: 'Cannot find on shelf' }
    post notonshelf_index_path, params: params

    expect(response.body).to include('Not On Shelf')

    staff_email = ActionMailer::Base.deliveries.last
    expect(staff_email.subject).to include('Search_Request')
    expect(staff_email.body).to include('Cannot find on shelf')
  end

  it 'renders error for non-existent bib' do
    sign_in FactoryBot.create(:happyuser)
    get notonshelf_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
