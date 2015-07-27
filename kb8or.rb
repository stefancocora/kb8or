#!/usr/bin/env ruby

# Tool to allow easy deployments on kb8
# by automating kubectl and managing versions

require 'methadone'
require 'yaml'
require 'pathname'

KB8_HOME = File.dirname(Pathname.new(__FILE__).realdirpath)
Dir.glob(File.join(KB8_HOME, 'libs/*.rb')) { |f| require f }

class Kb8or
  include Methadone::Main
  include Methadone::CLILogging

  version     File.read(File.join(KB8_HOME, 'version'))
  description 'Will create OR update a kb8 application in a re-runnable way'

  arg :deploy_file

  main do |deploy_file|
    unless File.exist?(deploy_file)
      puts "Please supply a valid file name!"
      exit 1
    end
    deploy = Deploy.new(deploy_file, options[:always_deploy], options[:env_name])
    deploy.deploy
  end

  opts.on("-a","--always-deploy","Ignore NoAutomaticUpgrade deployment setting") do
    options[:always_deploy] = true
  end

  opts.on("-e","--env","Specify the environment") do |env_name|
    options[:env_name] = env_name
  end

  use_log_level_option
  go!
end
