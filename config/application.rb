require_relative "boot"

# Valet doesn't need a lot of Rails - only load selected pieces
# require "rails/all"
require "rails"

require "active_model/railtie"
require "active_job/railtie"      # ActionMailer depends on it
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"


# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

VALET_VERSION = IO.read('VERSION').strip

module Valet
  class Application < Rails::Application
    config.load_defaults 7.2
    config.active_support.cache_format_version = 7.1

    # old gem
    # include Cul::Omniauth::FileConfigurable

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

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
