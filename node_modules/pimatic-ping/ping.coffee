# ##Dependencies
convict = require "convict"
util = require 'util'
ping = require "net-ping"
assert = require 'cassert'
Q = require 'q'

module.exports = (env) ->

  # ##The DevicePresentsBackend
  class DevicePresentsBackend extends env.plugins.Plugin
    server: null
    config: null

    # The `init` function just registers the clock actuator.
    init: (app, @server, @config) =>
      self = this
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      session = ping.createSession()
      assert Array.isArray self.config.devices
      for dc in config.devices
        assert dc.id?
        assert dc.name?
        assert dc.host? 
        device = new NetworkDevicePresents(dc.id, dc.name, dc.host, 
          (if dc.delay then dc.delay else 3000), session)
        server.registerSensor device

  backend = new DevicePresentsBackend

  # ##NetworkDevicePresents Sensor
  class NetworkDevicePresents extends env.sensors.Sensor
    config: null
    listener: []
    present: null
    interval: null

    constructor: (@id, @name, @host, @delay, @session) ->
      self = this
      self.interval = setInterval(self.ping, delay)

    getSensorValuesNames: ->
      "present"

    getSensorValue: (name)->
      self = this
      switch name
        when "present" then return Q.fcall -> self.present
        else throw new Error("Illegal sensor value name")

    canDecide: (predicate) ->
      self = this
      info = self.parsePredicate predicate
      return info?

    isTrue: (id, predicate) ->
      self = this
      info = self.parsePredicate predicate
      if info? then return Q.fcall -> info.present is self.present
      else throw new Error "NetworkDevicePresents sensor can not decide \"#{predicate}\"!"

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      self = this
      if self.listener[id]?
        delete self.listener[id]

    # Registers notification for time events. 
    notifyWhen: (id, predicate, callback) ->
      self = this
      info = self.parsePredicate predicate
      if info?
        self.listener[id] =
          id: id
          callback: callback
          present: info.present
      else throw new Error "NetworkDevicePresents sensor can not decide \"#{predicate}\"!"

    notifyListener: ->
      self = this
      for id of self.listener
        l = self.listener[id]
        if l.present is self.present
          l.callback()

    ping: => 
      self = this
      this.session.pingHost self.host, (error, target) ->
        if error
          if self.present isnt false
            self.present = false
            self.notifyListener()
        else
          if self.present isnt true  
            self.present = true
            self.notifyListener()

    parsePredicate: (predicate) ->
      self = this
      regExpString = '^(.+)\\s+is\\s+(not\\s+)?present$'
      matches = predicate.match (new RegExp regExpString)
      if matches?
        deviceName = matches[1].trim()
        if deviceName is self.name or deviceName is self.id
          return info =
            deviceId: self.id
            present: (if matches[2]? then no else yes) 
      return null

  # For testing...
  backend.NetworkDevicePresents = NetworkDevicePresents

  return backend