# spec/requests/omniauth_callbacks_spec.rb
#
# Users::OmniauthCallbacksController#columbia_cas is what actually runs when
# CAS bounces the browser back to us with a ticket. We stub
# Omniauth::Cul::ColumbiaCas.validation_callback (the part that talks to the
# real CAS server) so these specs exercise our own logic - user lookup/
# creation, affiliation assignment, and error handling - without a network
# dependency on cas.columbia.edu.
#
# Note: creating a new User still triggers a real LDAP lookup via
# User#set_personal_info_via_ldap (before_create), same as every other spec
# in this suite that does FactoryBot.create(:happyuser) - that's an existing
# characteristic of the suite, not something new introduced here.

RSpec.describe 'Omniauth Callbacks' do
  describe 'GET /users/auth/columbia_cas/callback' do
    it 'signs in an existing user and updates affiliations' do
      user = FactoryBot.create(:happyuser, uid: 'jdoe', affils: [])
      allow(Omniauth::Cul::ColumbiaCas).to receive(:validation_callback)
        .and_return(['jdoe', ['LIB_clio-Undergraduate']])

      get user_columbia_cas_omniauth_callback_path, params: { ticket: 'ST-123' }

      expect(response).to have_http_status(:redirect)
      user.reload
      expect(user.affils).to include('LIB_clio-Undergraduate')
      # the synthetic affil the callback always adds, in addition to whatever CAS returns
      expect(user.affils).to include('jdoe:users.cul.columbia.edu')
    end

    it 'creates a new user on first login' do
      allow(Omniauth::Cul::ColumbiaCas).to receive(:validation_callback)
        .and_return(['brandnewuid', []])

      expect do
        get user_columbia_cas_omniauth_callback_path, params: { ticket: 'ST-999' }
      end.to change(User, :count).by(1)

      expect(User.find_by(uid: 'brandnewuid')).to be_present
      expect(response).to have_http_status(:redirect)
    end

    it 'redirects to root with a flash notice when the CAS ticket is invalid' do
      allow(Omniauth::Cul::ColumbiaCas).to receive(:validation_callback)
        .and_raise(Omniauth::Cul::Exceptions::CasTicketValidationError, 'invalid ticket')

      get user_columbia_cas_omniauth_callback_path, params: { ticket: 'ST-bad' }

      expect(response).to redirect_to(root_url)
      follow_redirect!
      expect(flash[:notice]).to be_present
    end
  end
end
