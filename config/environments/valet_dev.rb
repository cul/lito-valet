# config/environments/valet_dev.rb
#
# Rebuilt against the Rails 7.2 production.rb template.
# Note: this is a *deployed* environment, not localhost -- it is
# production-like (eager loaded, no reloading), just chattier.
# Site-specific bits are marked SITE:

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here take precedence over config/application.rb.

  # === Code loading ===================================================
  # (was `config.cache_classes = true`, renamed in Rails 7.1)
  config.enable_reloading = false
  config.eager_load = true

  # === Error handling and caching =====================================
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Cache store is left at the Rails default (:file_store in tmp/cache).

  # === Static files ===================================================
  # NOTE: the old `config.serve_static_files = ...` line was a no-op --
  # that setting was renamed in Rails 5.0 and Rails silently ignored it,
  # so this app has in fact been serving /public through Rails all along.
  # `true` below preserves exactly that behavior.
  #
  # Once you've confirmed Apache/Passenger serves public/ directly, switch to:
  #   config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.public_file_server.enabled = true

  # === Assets =========================================================
  config.assets.compile = false
  config.assets.js_compressor = :terser
  # css_compressor is set to :sass automatically by the sassc-rails railtie.
  # (`config.assets.digest` was removed -- always on in Sprockets 4.)

  # === SSL ============================================================
  config.force_ssl = true
  # If the SSL-terminating proxy does not set X-Forwarded-Proto, add:
  # config.assume_ssl = true

  # === Logging ========================================================
  # This governs Rails' own logger only, which writes to
  # log/valet_dev.log. Capistrano links `log` to shared/log, so those
  # survive releases.
  #
  # Not to be confused with the application-layer activity log:
  # OffsiteRequestsController writes valet.YYYY-MM-DD.log files into
  # APP_CONFIG['log_directory'] and AdminController reads them back.
  # That path is independent of everything in this section.
  #
  # The stock 7.2 production.rb logs to STDOUT instead. Either works
  # under Passenger; file logging is kept here to match current behavior.
  config.log_level = :debug
  config.log_formatter = ::Logger::Formatter.new
  # config.log_tags = [:request_id]

  # === Deprecations ===================================================
  # Was `:notify`, which routed deprecations to ActiveSupport::Notifications
  # with no subscriber -- i.e. silently discarded them. This is the first
  # place Rails 8 deprecation warnings should show up.
  config.active_support.deprecation = :log
  config.active_support.report_deprecations = true

  # === Action Mailer ==================================================
  # Outgoing email is critical to this app: raise on delivery failure
  # rather than silently dropping requests.
  # Note that several services redirect staff email away from the real
  # recipients unless Rails.env.valet_prod? -- mail IS really sent here.
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: "valet-dev.cul.columbia.edu", protocol: "https"    # SITE:
  }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {                     # SITE:
    address:      "smtp.library.columbia.edu",
    domain:       "library.columbia.edu",
    port:         25,
    open_timeout: 10,
    read_timeout: 10
  }

  # === i18n ===========================================================
  config.i18n.fallbacks = true

  # === Active Record ==================================================
  config.active_record.dump_schema_after_migration = false
  # attributes_for_inspect left at the default (:all) for debuggability.

  # === Active Storage =================================================
  # Deliberately unset -- this app does not use Active Storage.

  # === Host authorization =============================================
  # config.hosts = ["valet-dev.cul.columbia.edu"]

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true
end
