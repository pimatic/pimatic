# ##Dependencies
convict = require "convict"
util = require 'util'
ping = require "net-ping"
assert = require 'cassert'
Q = require 'q'

module.exports = (env) ->

  # ##The DevicePresentsBackend
  class DevicePresentsBackend extends env.plugins.Plugin
    framework: null
    config: null

    # The `init` function just registers the clock actuator.
    init: (app, @framework, @config) =>
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      @session = ping.createSession()

    createSensor: (config) ->
      if @session? and config.class is 'PingPresents'
        assert config.id?
        assert config.name?
        assert config.host? 
        config.delay = (if config.delay then config.delay else 3000)
        sensor = new PingPresents config, @session
        @framework.registerSensor sensor
        return true
      return false


  backend = new DevicePresentsBackend

  # ##PingPresents Sensor
  class PingPresents extends env.sensors.PresentsSensor

    constructor: (@config, session) ->
      @id = config.id
      @name = config.name

      ping = => session.pingHost @config.host, (error, target) =>
        @_setPresent (if error then no else yes)

      @interval = setInterval(ping, config.delay)



  # For testing...
  backend.PingPresents = PingPresents

  return backend