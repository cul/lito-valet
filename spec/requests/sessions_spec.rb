# spec/requests/sessions_spec.rb
#
# Users::SessionsController#new redirects to CAS to start login.
# Users::SessionsController overrides #redirect_to so that ONLY a redirect to
# cas.columbia.edu is allowed to leave the host (Rails 7's raise_on_open_redirects,
# via config.load_defaults 7.0, blocks cross-host redirect_to by default). This
# is what makes /sign_out able to bounce the browser through CAS to kill the
# CAS session, not just Valet's local session - see
# ApplicationController#after_sign_out_path_for.

RSpec.describe 'Sessions' do
  describe 'GET /sign_in' do
    it 'redirects to the CAS omniauth authorize path' do
      get new_user_session_path
      expect(response).to redirect_to(user_columbia_cas_omniauth_authorize_path)
    end
  end

  describe 'GET /sign_out' do
    it 'allows the cross-host redirect to CAS so the CAS session is also killed' do
      sign_in FactoryBot.create(:happyuser)
      cas_logout_url = 'https://cas.columbia.edu/cas/logout?service=http://test.host/welcome/logout'
      allow_any_instance_of(Users::SessionsController)
        .to receive(:after_sign_out_path_for).and_return(cas_logout_url)

      expect { get destroy_user_session_path }.not_to raise_error
      expect(response).to redirect_to(cas_logout_url)
    end

    it 'does not allow a cross-host redirect to any host other than CAS' do
      sign_in FactoryBot.create(:happyuser)
      allow_any_instance_of(Users::SessionsController)
        .to receive(:after_sign_out_path_for).and_return('https://evil.example.com/whatever')

      expect { get destroy_user_session_path }
        .to raise_error(ActionController::Redirecting::UnsafeRedirectError)
    end

    it 'redirects normally for a local (same-host) sign-out path' do
      sign_in FactoryBot.create(:happyuser)
      allow_any_instance_of(Users::SessionsController)
        .to receive(:after_sign_out_path_for).and_return('/welcome/logout')

      get destroy_user_session_path
      expect(response).to redirect_to('/welcome/logout')
    end
  end
end
