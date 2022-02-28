source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.0'

# Use sqlite3 as the database for Active Record
gem 'sqlite3'

# Use SCSS for stylesheets
# gem 'sass-rails'
# sass-rails 6.x uses sassc, which won't build on our CentOS 6 VMs
gem 'sass-rails', '~> 5.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier'

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# # Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'

# # bundle exec rake doc:rails generates the API under doc/api.
# gem 'sdoc', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Testing
  gem 'rspec-rails'
  gem 'factory_bot'
end

group :development do
  # Let's use better_errors instead of this
  # # Access an IRB console on exception pages or by using <%= console %> in views
  # gem 'web-console', '~> 2.0'

  # gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'listen'

  # # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'spring'

  # browser-based live debugger and REPL
  # HAML REPL breaks in 2.7.0/2.7.1 ???
  # gem 'better_errors', '~> 2.6.0'
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
gem 'cul_omniauth', git: 'https://github.com/cul/cul_omniauth', branch: 'rails-6'


# Fetch ldap details - first name, last name, etc.
gem 'net-ldap'

# Talk to Voyager's Oracle DB, to e.g. fetch patron barcodes
gem 'ruby-oci8'

# Talk to our source for catalog records, a Solr search index
gem 'rsolr'

# Parse the MARC data structure of our catalog records
gem 'marc'

# marc uses rexml, and rexml was unbundled from the stdlib in ruby 3
gem 'rexml'

# Normalization of ISBN (10 and 13), ISSN, and LCCN
gem 'library_stdnums'

# Use Twitter Bootstrap for styling
#  pin to old version, newer needs sassc, which needs libc, which needs CentOS > 6
gem 'bootstrap-sass', '~> 3.3.0'

# Talk to SCSB REST API
# gem 'rest-client'
gem 'faraday'

# Talk to HTTP servers
gem 'httpclient'

# Use MySQL for deployed server environments
gem 'mysql2'

# Talk to SCSB ActiveMQ via STOMP
gem 'stomp'

# DataTables
gem 'jquery-datatables-rails'

# Send notifications when application errors occur
gem 'exception_notification'

# Parse User Agent into browser name, version
gem 'browser'

# Some services (e.g., paging) want to log a sortable call number
gem 'lcsort'

# dependency of many other gems
# need to pin to 1.10, due to old libc on CentOS 6
gem 'nokogiri', '~> 1.13.2'

# now fixed.
# # UNIX-5942 - work around spotty CUIT DNS
# gem 'resolv-hosts-dynamic'

