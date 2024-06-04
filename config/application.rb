require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

VALET_VERSION = IO.read('VERSION').strip

module Valet
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Only needed up to 6.x / in 7.x and beyond, autoloader is always Zeitwerk
    config.autoloader = :zeitwerk

    include Cul::Omniauth::FileConfigurable

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # https://mattbrictson.com/dynamic-rails-error-pages
    config.exceptions_app = routes

    # set ActiveRecord timestamps (e.g., 'created_at') to local time 
    config.time_zone = 'Eastern Time (US & Canada)'
    config.active_record.default_timezone = :local # Or :utc

  end
end
