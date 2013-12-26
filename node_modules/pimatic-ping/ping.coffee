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
    config: null
    listener: []
    present: null
    interval: null

    constructor: (@config, @session) ->
      @id = config.id
      @name = config.name
      @interval = setInterval( => 
        @ping()
      , 
        @config.delay
      )

    getSensorValuesNames: ->
      "present"

    getSensorValue: (name)->
      switch name
        when "present" then return Q.fcall => @present
        else throw new Error("Illegal sensor value name")

    canDecide: (predicate) ->
      info = @parsePredicate predicate
      return info?

    isTrue: (id, predicate) ->
      info = @parsePredicate predicate
      if info? then return Q.fcall => info.present is @present
      else throw new Error "PingPresents sensor can not decide \"#{predicate}\"!"

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      if @listener[id]?
        delete @listener[id]

    # Registers notification for time events. 
    notifyWhen: (id, predicate, callback) ->
      info = @parsePredicate predicate
      if info?
        @listener[id] =
          id: id
          callback: callback
          present: info.present
      else throw new Error "PingPresents sensor can not decide \"#{predicate}\"!"

    notifyListener: ->
      for id of @listener
        l = @listener[id]
        if l.present is @present
          l.callback()

    ping: -> 
      @session.pingHost @config.host, (error, target) =>
        if error
          if @present isnt false
            @present = false
            @notifyListener()
        else
          if @present isnt true  
            @present = true
            @notifyListener()

    parsePredicate: (predicate) ->
      regExpString = '^(.+)\\s+is\\s+(not\\s+)?present$'
      matches = predicate.match (new RegExp regExpString)
      if matches?
        deviceName = matches[1].trim()
        if deviceName is @name or deviceName is @id
          return info =
            deviceId: @id
            present: (if matches[2]? then no else yes) 
      return null

  # For testing...
  backend.PingPresents = PingPresents

  return backend