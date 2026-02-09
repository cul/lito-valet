# spec/models/clio_record_spec.rb

require 'rails_helper'

RSpec.describe ClioRecord, type: :model do
  # LIBSYS-3139 - Call Numbers
  it 'ClioRecord shows local call-number, not 050 call-number' do
    # local "g" suffix at the end of the publication date in the call number
    bib_record = ClioRecord.new_from_bib_id(14446352)
    expect(bib_record.call_number).to eq 'GV945.6.S6 R53 2019g'

    # non-LC call numbers used in department libraries
    bib_record = ClioRecord.new_from_bib_id(360487)
    expect(bib_record.call_number).to eq 'ND239 R726 G56'
  end
end
