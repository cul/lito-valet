
RSpec.describe 'BearStor Request Service' do

  it 'BearStor request renders form' do
    sign_in FactoryBot.create(:happyuser)
    get bearstor_path('5060332')
    expect(response.body).not_to include('record has no BearStor holdings')
    expect(response.body).not_to include('error')
    expect(response.body).to include('BearStor Request')
  end

  it 'BearStor form submission renders confirm and sends email' do
    user = FactoryBot.create(:happyuser)
    sign_in user
    params = { id: '5060332', itemBarcodes: ['0036014419'] }
    post bearstor_index_path, params: params

    # confirm page
    expect(response.body).to include('BearStor Confirmation')

    # two emails - confirm to user, request to staff
    staff_email, confirm_email = ActionMailer::Base.deliveries.last(2)
    # staff email
    expect(staff_email.from).to include(APP_CONFIG[:bearstor][:staff_email])
    expect(staff_email.to).to include(APP_CONFIG[:bearstor][:staff_email])
    expect(staff_email.subject).to include('New BearStor request')
    expect(staff_email.body).to include('BARCODE: 0036014419')
    expect(staff_email.body).to include('following has been requested from BearStor')
    # confirm email
    expect(confirm_email.from).to include(APP_CONFIG[:bearstor][:staff_email])
    expect(confirm_email.to).to include(user[:email])
    expect(confirm_email.subject).to include('BearStor Request Confirmation')
    expect(staff_email.body).to include('BARCODE: 0036014419')
    expect(confirm_email.body).to include('You have requested the following from BearStor')
  end

  it 'rejects BearStor requests for non-BearStor items' do
    sign_in FactoryBot.create(:happyuser)
    get bearstor_path('123')
    expect(response.body).to include('record has no BearStor holdings')
  end

  it 'rejects BearStor requests for Partner ReCAP items' do
    sign_in FactoryBot.create(:happyuser)
    get bearstor_path('SCSB-1441991')
    expect(response.body).to include('record has no BearStor holdings')
  end

  it 'bounces unauth user to sign-in page' do
    get bearstor_path('123')
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existant item' do
    sign_in FactoryBot.create(:happyuser)
    # CLIO has no bib id 60
    get bearstor_path('60')
    expect(response.body).to include('Cannot find bib record')
  end
end
