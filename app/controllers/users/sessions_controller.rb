#  old gem
# class Users::SessionsController < Devise::SessionsController
#   def new_session_path(_scope)
#     new_user_session_path # this accomodates Users namespace of the controller
#   end
#
#   def omniauth_provider_key
#     # there is support for :wind, :cas, and :saml in Cul::Omniauth
#   end
#
#   # (Without this, visit /users/auth/saml explicitly)
#   # GET /resource/sign_in
#   def new
#     redirect_to user_saml_omniauth_authorize_path
#   end
# end

# new gem
class Users::SessionsController < Devise::SessionsController


  def new_session_path(_scope)
    new_user_session_path # this accomodates Users namespace of the controller
  end

  # (Without this, visit /users/auth/columbia_cas explicitly)
  # GET /resource/sign_in
  def new
    redirect_to user_columbia_cas_omniauth_authorize_path
  end


  private 

  # Allow off-host redirects, to the CAS server only (hardcoded)
  def redirect_to(options = {}, response_options = {})
    # parse the passed full redirect URL to find just the host portion
    if options.is_a?(String)
      host = begin
        URI(options).host
      rescue URI::InvalidURIError
        nil
      end
      response_options = response_options.merge(allow_other_host: true) if host == 'cas.columbia.edu'
    end
    super(options, response_options)
  end


end
