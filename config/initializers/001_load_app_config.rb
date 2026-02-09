begin
  # No interpolation
  #   raw_config = File.read(Rails.root.to_s + '/config/app_config.yml')
  #   loaded_config = YAML.load(raw_config)
  # Interpolation
  app_config_file = Rails.root.to_s + '/config/app_config.yml'
  loaded_config = YAML.load(ERB.new(IO.read(app_config_file)).result) || {}
  loaded_config = HashWithIndifferentAccess.new(loaded_config)

  all_config = loaded_config['_all_environments'] || {}
  env_config = loaded_config[Rails.env] || {}
  APP_CONFIG ||= all_config.merge(env_config)

rescue
  APP_CONFIG = {}.freeze
end

LOCATIONS ||= YAML.load(File.read(Rails.root.to_s + '/config/locations.yml'))

DELIVERY ||= YAML.load(File.read(Rails.root.to_s + '/config/delivery.yml'))
