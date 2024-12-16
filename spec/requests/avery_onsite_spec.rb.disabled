RSpec.describe 'Avery Onsite Request Service' do

  # sample data:
  # bib 123456  - "Tanguy Prigent", Offsite (off,glx)
  # bib 9325611 - "Reading architecture", Avery Reference (avelc,ref)
  

  it 'renders On-Site Use form for Avery title' do
    sign_in FactoryBot.create(:happyuser)
    get avery_onsite_path('9325611')
    expect(response.body).to include('Avery On-Site Use')
  end
  
  it 'fails for non-Avery title' do
    sign_in FactoryBot.create(:happyuser)
    get avery_onsite_path('123456')
    expect(response.body).to include('record has no Avery holdings')
  end

end