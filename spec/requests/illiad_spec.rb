RSpec.describe 'ILLiad' do
  it 'redirects authorized users to ILLiad' do
    sign_in FactoryBot.create(:happyuser)

    illiad_login_url = APP_CONFIG[:illiad_login_url]

    get '/illiad'
    expect(response).to redirect_to(illiad_login_url)
  end

  it 'redirects unauthorized users to ineligible URL' do
    sign_in FactoryBot.create(:blockeduser)

    ineligible_url = APP_CONFIG[:illiad][:ineligible_url]

    get '/illiad'
    expect(response).to redirect_to(ineligible_url)
  end
end
