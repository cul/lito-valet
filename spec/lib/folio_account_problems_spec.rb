# spec/lib/folio_account_problems_spec.rb
#
# Unit tests for Folio::Client.get_account_problems_by_uni (LIBSYS-8360)
# FOLIO API calls are stubbed; no live FOLIO access needed.

RSpec.describe Folio::Client do
  let(:good_user) do
    {
      'id'             => '3d5ac903-2f2b-5894-888f-a4dceeea1fbd',
      'username'       => 'sam119',
      'active'         => true,
      'expirationDate' => 1.year.from_now.iso8601
    }
  end

  before do
    allow(Folio::Client).to receive(:get_blocks_by_user_id).and_return([])
  end

  def problems_for(folio_user)
    allow(Folio::Client).to receive(:get_user_by_uni).and_return(folio_user)
    Folio::Client.get_account_problems_by_uni('sam119')
  end

  it 'finds no problems for an active, unexpired, unblocked user' do
    expect(problems_for(good_user)).to eq([])
  end

  it 'flags an inactive user' do
    expect(problems_for(good_user.merge('active' => false))).to include('inactive account')
  end

  it 'flags an expired user' do
    expired = good_user.merge('expirationDate' => '2020-01-01T00:00:00.000+00:00')
    expect(problems_for(expired).first).to start_with('expired account')
  end

  it 'flags a blocked user' do
    allow(Folio::Client).to receive(:get_blocks_by_user_id).and_return(['Patron has fines'])
    expect(problems_for(good_user)).to eq(['block: Patron has fines'])
  end

  it 'reports multiple problems together' do
    allow(Folio::Client).to receive(:get_blocks_by_user_id).and_return(['Patron has fines'])
    bad = good_user.merge('active' => false, 'expirationDate' => '2020-01-01T00:00:00.000+00:00')
    expect(problems_for(bad).size).to eq(3)
  end

  it 'treats a missing expirationDate as not expired' do
    expect(problems_for(good_user.except('expirationDate'))).to eq([])
  end

  it 'treats a missing active flag as active' do
    expect(problems_for(good_user.except('active'))).to eq([])
  end

  it 'fails open when the user is not found in FOLIO' do
    expect(problems_for({})).to eq([])
  end

  it 'returns no problems for a blank uni' do
    expect(Folio::Client.get_account_problems_by_uni(nil)).to eq([])
  end
end
