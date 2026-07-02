# old gem
# class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
#   include Cul::Omniauth::Callbacks
#
#   def new_session_path(_scope)
#     new_user_session_path # this accomodates Users namespace of the controller
#   end
#
#   def affiliations(user, affils)
#     return unless user
#
#     user.affils = affils.sort
#   end
# end

# new gem
require 'omniauth/cul'

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # The CAS redirect back to us, and the developer_uid form post, don't carry
  # Rails authenticity tokens (see omniauth-cul README + CVE-2015-9284 notes
  # in config/initializers/omniauth.rb), so skip verification for these actions.
  skip_before_action :verify_authenticity_token, only: [:columbia_cas, :developer_uid]

  def new_session_path(_scope)
    new_user_session_path # this accomodates Users namespace of the controller
  end

  # POST /users/auth/columbia_cas/callback
  def columbia_cas
    callback_url = user_columbia_cas_omniauth_callback_url
    uid, affils = Omniauth::Cul::ColumbiaCas.validation_callback(request.params['ticket'], callback_url)

    user = User.find_for_columbia_cas(uid)
    affiliations(user, affils)

    if user&.persisted?
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'CAS'
      sign_in_and_redirect user, event: :authentication
    else
      handle_auth_failure('CAS', 'no persisted user for id', uid: uid)
    end
  rescue Omniauth::Cul::Exceptions::Error => e
    error_message = 'CAS login validation failed. Please try again.'
    Rails.logger.debug("#{error_message} #{e.class.name}: #{e.message}")
    handle_auth_failure('CAS', error_message)
  end

  # POST /users/auth/developer_uid/callback
  # Only reachable in development (see :developer_uid entry in devise.rb),
  # but guard here too in case config is ever mis-set.
  def developer_uid
    return head(:not_found) unless Rails.env.development?

    uid = params[:uid]
    user = User.find_by(uid: uid)

    if user
      sign_in_and_redirect user, event: :authentication
    else
      flash[:alert] = "Login attempt failed. User #{uid} does not have an account."
      redirect_to root_path
    end
  end

  def affiliations(user, affils)
    return unless user

    all_affils = Array(affils) + ["#{user.uid}:users.cul.columbia.edu"]
    user.affils = all_affils.sort
    user.save!
    session['devise.roles'] = user.affils
  end

  def after_sign_in_path_for(resource)
    session[:return_to] || super
  end

  private

  def handle_auth_failure(kind, reason, uid: nil)
    Rails.logger.warn("#{reason} uid=#{uid.inspect}")
    flash[:notice] = I18n.t 'devise.omniauth_callbacks.failure', kind: kind, reason: reason
    redirect_to root_url
  end
end
