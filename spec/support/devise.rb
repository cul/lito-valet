# https://github.com/plataformatec/devise#test-helpers
RSpec.configure do |config|
  # Controller tests
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  # Integration tests
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :request
end
