# spec/models/user_spec.rb

RSpec.describe User, type: :model do
  describe '#valet_admin?' do
    it 'returns true for user with CUL_allstaff affil' do
      user = FactoryBot.build(:happyuser, affils: ['CUL_allstaff'])
      expect(user.valet_admin?).to be true
    end

    it 'returns false for regular user' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_clio-Undergraduate'])
      expect(user.valet_admin?).to be false
    end
  end

  describe '#culstaff?' do
    it 'returns true for user with CUL_allstaff affil' do
      user = FactoryBot.build(:happyuser, affils: ['CUL_allstaff'])
      expect(user.culstaff?).to be true
    end

    it 'returns true for user with LIB_allstaff affil' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_allstaff'])
      expect(user.culstaff?).to be true
    end

    it 'returns false for non-staff user' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_clio-Undergraduate'])
      expect(user.culstaff?).to be false
    end
  end

  describe '#offsite_eligible?' do
    it 'returns true for user with eligible affil' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_clio-Undergraduate'])
      expect(user.offsite_eligible?).to be true
    end

    it 'returns false for user with no affils' do
      user = FactoryBot.build(:happyuser, affils: [])
      expect(user.offsite_eligible?).to be false
    end
  end

  describe '#offsite_blocked?' do
    it 'returns true for user with blocked affil' do
      user = FactoryBot.build(:happyuser, affils: ['CUL_role-clio-REG-blocked'])
      expect(user.offsite_blocked?).to be true
    end

    it 'returns false for user without blocked affil' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_clio-Undergraduate'])
      expect(user.offsite_blocked?).to be false
    end
  end

  describe '#patron_groups' do
    it 'extracts patron group from CUL_role affil' do
      user = FactoryBot.build(:happyuser, affils: ['CUL_role-clio-REG'])
      expect(user.patron_groups).to include('REG')
    end

    it 'extracts patron group from LIB_clio affil' do
      user = FactoryBot.build(:happyuser, affils: ['LIB_clio-Undergraduate'])
      expect(user.patron_groups).to include('Undergraduate')
    end

    it 'returns empty array for user with no affils' do
      user = FactoryBot.build(:happyuser, affils: [])
      expect(user.patron_groups).to be_empty
    end
  end
end
