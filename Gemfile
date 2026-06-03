source 'https://rubygems.org'

gem 'rails', '~> 7.0.0'

# https://stackoverflow.com/questions/79360526/uninitialized-constant
# uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger
#   Remove this when we update Rails to 7.1
gem 'concurrent-ruby', '1.3.4'

# Valet is built using Sprockets
gem 'sprockets-rails'

# Use SCSS for stylesheets
gem 'sass-rails'

# Use Terser as compressor for JavaScript assets
gem 'terser'

# # Use CoffeeScript for .coffee assets and views
# gem 'coffee-rails'

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

group :development, :test do
  # Use sqlite3 as the database for Active Record - only during localhost development
  # gem 'sqlite3'
  # # sqlite 2.0.x is giving us problems - pin to 1.x for now
  # gem 'sqlite3', '~> 1.0'
  # Still a problem with rails/sqlite mismatch, but 1.5 is ok
  gem 'sqlite3', '~> 1.5'

  # Testing
  gem 'rspec-rails'
  gem 'factory_bot'
end

group :development do
  # Which server do we want to use on localhost?
  # gem 'webrick'
  gem 'puma'

  # gem 'listen', '>= 3.0.5', '< 3.2'
  # marginal improvement, not necessary
  # gem 'listen'

  # Uncomment these when you want to run some RuboCop cleanup
  # gem 'rubocop', require: false
  # gem 'rubocop-rails', require: false

  # browser-based live debugger and REPL
  gem 'better_errors'
  # And get a REPL
  gem 'binding_of_caller'

  # Deployment with Capistrano
  gem 'capistrano', '~> 3.0', require: false
  # Rails and Bundler integrations were moved out from Capistrano 3
  gem 'capistrano-rails', require: false
  gem 'capistrano-bundler', require: false
  # "idiomatic support for your preferred ruby version manager"
  gem 'capistrano-rvm', require: false
  # The `deploy:restart` hook for passenger applications is now in a separate gem
  # Just add it to your Gemfile and require it in your Capfile.
  gem 'capistrano-passenger', require: false
end

# Authentication
# gem 'devise', '~> 4.4.0'
gem 'devise'

# gem 'cul_omniauth'
# gem 'cul_omniauth', github: 'cul/cul_omniauth', branch: 'rails-5'
# gem 'cul_omniauth', path: '/Users/marquis/src/cul_omniauth'
# gem 'cul_omniauth', git: 'https://github.com/cul/cul_omniauth', branch: 'cas-5.3'
# gem 'cul_omniauth', git: 'https://github.com/cul/cul_omniauth', branch: 'rails-6'
gem 'cul_omniauth'

# Fetch ldap details - first name, last name, etc.
gem 'net-ldap'

# Talk to FOLIO, using Stanford's client library
gem 'folio_client'

# # Talk to Voyager's Oracle DB, to e.g. fetch patron barcodes
# gem 'ruby-oci8'

# Talk to our source for catalog records, a Solr search index
gem 'rsolr'

# Parse the MARC data structure of our catalog records
gem 'marc'

# marc uses rexml, and rexml was unbundled from the stdlib in ruby 3
gem 'rexml'

# Normalization of ISBN (10 and 13), ISSN, and LCCN
gem 'library_stdnums'

# Use Twitter Bootstrap for styling
gem 'bootstrap-sass'

# Talk to SCSB REST API
# gem 'rest-client'
gem 'faraday'
# Silence "already initialized constant" warnings
#   reference:  https://github.com/ruby/net-imap/issues/16
gem 'net-http'

# Talk to HTTP servers
gem 'httpclient'

# Use MySQL for deployed server environments
gem 'mysql2'

# We don't talk ActiveMQ yet
# # Talk to SCSB ActiveMQ via STOMP
# gem 'stomp'

# DataTables
gem 'jquery-datatables-rails'

# Parse User Agent into browser name, version
gem 'browser'

# Some services (e.g., paging) want to log a sortable call number
gem 'lcsort'

# dependency of many other gems
# gem 'nokogiri'
# Pin nokogiri to 1.17.x, glibc version incompatibility with 1.18.x
# /lib64/libm.so.6: version `GLIBC_2.29' not found
gem 'nokogiri', '~> 1.17.0'

# now fixed.
# # UNIX-5942 - work around spotty CUIT DNS
# gem 'resolv-hosts-dynamic'
