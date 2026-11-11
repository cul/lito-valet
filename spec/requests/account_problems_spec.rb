# spec/requests/account_problems_spec.rb
#
# LIBSYS-8360 - Patrons whose FOLIO account is blocked, inactive, or expired
# are redirected to a single account-problem page for any authenticated service.
# The FOLIO lookup is stubbed so these tests don't depend on live patron data.

RSpec.describe 'FOLIO account problems' do
  it 'redirects a patron with a FOLIO account problem to the account-problem page' do
    allow(Folio::Client).to receive(:get_account_problems_by_uni).and_return(['inactive account'])
    sign_in FactoryBot.create(:happyuser)

    get borrow_direct_path('123')
    expect(response).to redirect_to(APP_CONFIG[:patron_account_problem_url])
  end

  it 'uses the same page regardless of service' do
    allow(Folio::Client).to receive(:get_account_problems_by_uni).and_return(['block: Patron has fines'])
    sign_in FactoryBot.create(:happyuser)

    get ill_scan_path('123')
    expect(response).to redirect_to(APP_CONFIG[:patron_account_problem_url])
  end

  it 'still uses the service-specific ineligible URL for affiliation problems' do
    allow(Folio::Client).to receive(:get_account_problems_by_uni).and_return([])
    sign_in FactoryBot.create(:blockeduser)

    get borrow_direct_path('123')
    expect(response).to redirect_to(APP_CONFIG[:borrow_direct][:ineligible_url])
  end
end
