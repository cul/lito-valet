# server 'valet-test.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
#
# set :deploy_to, '/opt/passenger/lito/valet_test'

# Alma
server 'lito-rails-test1.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
set :deploy_to, '/opt/passenger/valet_test'
set :rvm_ruby_version, 'valet_test'
