

RSpec.describe 'StarrStor Request Service' do

  it 'StarrStor request renders form' do
    sign_in FactoryBot.create(:happyuser)
    get starrstor_path('12892723')
    expect(response.body).not_to include('no StarrStor holdings')
    expect(response.body).not_to include('error')
    expect(response.body).to include('StarrStor Request')
  end

  it 'StarrStor form submission renders confirm and sends email' do
    user = FactoryBot.create(:happyuser)
    sign_in user
    params = { id: '12892723', itemBarcodes: ['0073113476'] }
    post starrstor_index_path, params: params

    # confirm page
    expect(response.body).to include('StarrStor Confirmation')

    # two emails - confirm to user, request to staff
    staff_email, confirm_email = ActionMailer::Base.deliveries.last(2)

    # N.B., for StarrStor, we hard-code the "From" address, because it's 
    # different from the staff-email (which includes Clancy/CaiaSoft staff)

    # staff email
    expect(staff_email.from).to include('starrstor@library.columbia.edu')
    expect(staff_email.to).to include(APP_CONFIG[:starrstor][:staff_email])
    expect(staff_email.subject).to include('New StarrStor request')
    expect(staff_email.body).to include('BARCODE: 0073113476')
    expect(staff_email.body).to include('following has been requested from StarrStor')
    # confirm email
    expect(staff_email.from).to include('starrstor@library.columbia.edu')
    expect(confirm_email.to).to include(user[:email])
    expect(confirm_email.subject).to include('StarrStor Request Confirmation')
    expect(staff_email.body).to include('BARCODE: 0073113476')
    expect(confirm_email.body).to include('You have requested the following from StarrStor')
  end

  it 'rejects StarrStor requests for non-StarrStor items' do
    sign_in FactoryBot.create(:happyuser)
    get starrstor_path('123')
    expect(response.body).to include('record has no StarrStor holdings')
  end

  it 'rejects StarrStor requests for Partner ReCAP items' do
    sign_in FactoryBot.create(:happyuser)
    get starrstor_path('SCSB-1441991')
    expect(response.body).to include('record has no StarrStor holdings')
  end

  it 'bounces unauth user to sign-in page' do
    get starrstor_path('123')
    expect(response.body).to redirect_to('http://www.example.com/sign_in')
  end

  it 'renders error page for non-existant item' do
    sign_in FactoryBot.create(:happyuser)
    # CLIO has no bib id 60
    get starrstor_path('60')
    expect(response.body).to include('Cannot find bib record')
  end

  # FOLIO-132 - Remove support for StarrStor Inactive Barcodes
  # # LIBSYS-5996 - StarrStor - include inactive barcodes in staff request emails
  # # Bib used for example: https://clio.columbia.edu/catalog/76
  # it 'retrieves inactive barcodes for an active barcode' do
  #   oracle_connection ||= Voyager::OracleConnection.new
  #   inactive_barcodes = oracle_connection.retrieve_inactive_barcodes('CU16572637')
  #   expect(inactive_barcodes).to have_attributes(size: 1)
  #   expect(inactive_barcodes.first).to eq('0315337170')
  # end

end
