
# server 'valet-dev.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
# set :deploy_to, '/opt/passenger/lito/valet_dev'

# Alma
server 'lito-rails-dev1.cul.columbia.edu', user: 'litoserv', roles: %w(app db web)
set :deploy_to, '/opt/passenger/valet_dev'
set :rvm_ruby_version, 'valet_alma'

# If for some reason we're not on campus or on VPN,
# we can deploy via a jumphost, as follows:
# (taken from https://gist.github.com/peterhellberg/e823e3f73495e17f1f02 )
# set :user, 'litoserv'
# set :jumphost, 'connect.cul.columbia.edu'
#
# set :ssh_options, {
#   user: fetch(:user),
#   forward_agent: false,
#   proxy: Net::SSH::Proxy::Command.new(
#     "ssh -l #{fetch(:user)} #{fetch(:jumphost)} -W %h:%p"
#   )
# }
