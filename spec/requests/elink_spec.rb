# spec/requests/elink_spec.rb

RSpec.describe 'E-Link' do
  it 'redirects authorized user to vendor endpoint with OpenURL params' do
    sign_in FactoryBot.create(:happyuser)

    vendor_endpoint = APP_CONFIG[:elink][:vendor_endpoint]

    get '/elink', params: { 'rft.issn' => '1234-5678', 'rft.title' => 'Test Journal' }
    expect(response).to redirect_to(/\A#{Regexp.escape(vendor_endpoint)}/)
    expect(response.location).to include('rft.issn')
    expect(response.location).to include('1234-5678')
  end
end
