#!/usr/bin/env ruby

# Copyright 2018 Jef Spaleta and contributors.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# In order to use this plugin, you must first configure a
# particle.io cloud api account
# You'll make use of the particle.io login information
#

require 'sensu-plugin/metric/cli'
require 'particle'
require 'json'

class MetricParticle < Sensu::Plugin::Metric::CLI::Graphite
  option :particle_config_file,
         description: 'Particle config JSON file location',
         short: '-c CONFIG_FILE',
         long: '--config_file CONFIG_FILE'
  option :particle_user,
         description: 'Particle user',
         short: '-u USER',
         long: '--user USER'
  option :particle_password,
         description: 'Particle password',
         short: '-p PASSWORD',
         long: '--password PASSWORD'
  option :particle_token,
         description: 'Particle access token',
         short: '-t TOKEN',
         long: '--token TOKEN',
         default: ENV['PARTICLE_ACCESS_TOKEN']
  option :particle_device,
         description: 'Particle device id or device name',
         short: '-d DEVICE',
         long: '--device DEVICE'
  option :particle_variable,
         description: 'Particle device variable name',
         short: '-V VARIABLE_NAME',
         long: '--variable VARIABLE_NAME'
  option :verbose,
         description: 'Verbose output',
         short: '-v',
         long: '--verbose'

  ##
  # Setup helper function to deal with configuration processing
  ##
  def setup
    if config.key?(:particle_config_file)
      if File.readable?(config[:particle_config_file])
        file = File.read(config[:particle_config_file])
        config_hash = JSON.parse(file)
        keys = %w[particle_user particle_password particle_token particle_device particle_variable]
        keys.each do |key|
          config[key.to_sym] = config_hash[key] if config_hash.key?(key)
        end
      end
    end

    unless (config[:particle_user] && config[:particle_password]) || config[:particle_token]
      critical 'Must supply user and password or token, check --help message for more information'
    end

    unless config[:particle_device]
      critical 'Must supply particle device, check --help message for more information'
    end

    unless config[:particle_variable]
      critical 'Must supply particle device variable, check --help message for more information'
    end

    return unless config[:verbose]
  end

  def run
    setup
    client = Particle::Client.new
    client.access_token = config[:particle_token] if config[:particle_token]
    client.login(config[:particle_user], config[:particle_password]) if config[:particle_user] && config[:particle_password]

    device = client.device(config[:particle_device])
    unless device.ping
      critical "error: device #{config[:particle_device]} is offline"
    end

    val = device.variable(config[:particle_variable])
    output "particle.#{config[:particle_device]}.#{config[:particle_variable]}", val
    ok
  rescue Particle::Forbidden, Particle::BadRequest, Particle::MissingTokenError => e
    critical "error: #{e.message}"
  end
end
