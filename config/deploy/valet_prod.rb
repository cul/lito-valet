
# server 'valet.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
#
# set :deploy_to, '/opt/passenger/lito/valet_prod'


# Alma
server 'lito-rails-prod1.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
set :deploy_to, '/opt/passenger/valet_prod'
set :rvm_ruby_version, 'valet_alma'

