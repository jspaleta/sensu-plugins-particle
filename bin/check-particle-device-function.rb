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

require 'sensu-plugin/check/cli'
require 'particle'
require 'json'

class CheckParticle < Sensu::Plugin::Check::CLI
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
  option :particle_function,
         description: 'Particle device function name',
         short: '-f FUNCTION_NAME',
         long: '--function FUNCTION_NAME'
  option :particle_argument,
         description: 'Particle device function argument',
         short: '-a FUNCTION_ARGUMENT',
         long: '--argument FUNCTION_ARGUMENT'
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
        keys = %w[particle_user particle_password particle_token particle_device particle_function particle_argument]
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

    unless config[:particle_function]
      critical 'Must supply particle device function, check --help message for more information'
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

    result = device.call(config[:particle_function], config[:particle_argument])
    ok if result.zero?
    warning if result == 1
    critical if result == 2
    unknown if result > 2 || result < 0
  rescue Particle::Forbidden, Particle::BadRequest, Particle::MissingTokenError => e
    critical "error: #{e.message}"
  end
end
