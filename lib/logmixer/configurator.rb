class LogMixer::Configurator
  def initialize
  end

  def reload
    instance_eval(File.read(config_file), config_file) if config_file
  end
end