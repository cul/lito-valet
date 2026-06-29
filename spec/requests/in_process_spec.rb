# spec/requests/in_process_spec.rb

RSpec.describe 'In Process Request Service' do
  # Bib 10897690 has holdings with "On Order" or "In Process" call numbers
  it 'in_process request renders form' do
    sign_in FactoryBot.create(:happyuser)
    get in_process_path('1000860')
    expect(response.body).not_to include('no holdings On Order or In Process')
    expect(response.body).not_to include('error')
    expect(response.body).to include('In Process')
  end

  it 'rejects in_process requests for items not on order or in process' do
    sign_in FactoryBot.create(:happyuser)
    # Bib 123 is a known good bib with regular holdings
    get in_process_path('123')
    expect(response.body).to include('no holdings On Order or In Process')
  end

  it 'in_process form submission renders confirm and sends email' do
    user = FactoryBot.create(:happyuser)
    sign_in user

    bib_record = ClioRecord.new_from_bib_id('1000860')
    holding = bib_record.holdings.first
    params = { id: '1000860', mfhd_id: holding[:mfhd_id], pickup: 'Butler Library', note: 'test note' }
    post in_process_index_path, params: params

    expect(response.body).to include('In Process')

    staff_email = ActionMailer::Base.deliveries.last
    expect(staff_email.subject).to include('In Process')
  end

  it 'bounces unauthenticated user to sign-in page' do
    get in_process_path('1000860')
    expect(response).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existent bib' do
    sign_in FactoryBot.create(:happyuser)
    get in_process_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
