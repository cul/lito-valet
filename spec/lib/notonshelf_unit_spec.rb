# spec/lib/notonshelf_spec.rb
#
# Unit tests for Service::Notonshelf#get_email_alias_for_location
# Tests a representative sample of the routing rules, not every pattern.

RSpec.describe Service::Notonshelf do
  let(:service) { Service::Notonshelf.new(APP_CONFIG[:notonshelf]) }

  describe '#get_email_alias_for_location' do
    it 'routes Butler location to Butler circulation' do
      expect(service.send(:get_email_alias_for_location, 'bar,mil'))
        .to eq('butler_circulation@libraries.cul.columbia.edu')
    end

    it 'routes Barnard location to Barnard circulation' do
      expect(service.send(:get_email_alias_for_location, 'bwc'))
        .to eq('barnard_circulation@libraries.cul.columbia.edu')
    end

    it 'routes Avery location to Avery circulation' do
      expect(service.send(:get_email_alias_for_location, 'ava'))
        .to eq('avery_circulation@libraries.cul.columbia.edu')
    end

    it 'routes East Asian location to Starr East Asian circulation' do
      expect(service.send(:get_email_alias_for_location, 'eal'))
        .to eq('starr_east_asian_circulation@libraries.cul.columbia.edu')
    end

    it 'routes Music location to Music circulation' do
      expect(service.send(:get_email_alias_for_location, 'mus'))
        .to eq('music_circulation@libraries.cul.columbia.edu')
    end

    it 'routes Health Sciences location to Health Sciences circulation' do
      expect(service.send(:get_email_alias_for_location, 'hsl'))
        .to eq('health_sciences_circulation@libraries.cul.columbia.edu')
    end

    it 'defaults unknown location code to Butler circulation' do
      expect(service.send(:get_email_alias_for_location, 'xyz'))
        .to eq('butler_circulation@libraries.cul.columbia.edu')
    end
  end
end
