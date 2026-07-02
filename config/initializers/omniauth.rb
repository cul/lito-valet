# old gem - fully commented out
# # CUIT server setting here:
# #     http://cuit.columbia.edu/cas-authentication#Configuration_Options
#
# Rails.application.config.middleware.use OmniAuth::Builder do
#
#   provider :cas,
#     host: 'cas.columbia.edu',
#     login_url:  '/cas/login',
#     logout_url: '/cas/logout',
#     service_validate_url: '/cas/samlValidate'
#     # disable_ssl_verification: true
#
# end
#
#

# new gem
# Mitigate CVE-2015-9284.
# See https://github.com/cookpad/omniauth-rails_csrf_protection?tab=readme-ov-file#omniauth---rails-csrf-protection
OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)

OmniAuth.config.allowed_request_methods = %i[get post]




