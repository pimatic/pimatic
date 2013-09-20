convict = require "convict"
util = require 'util'
ping = require "net-ping"
assert = require 'cassert'
# * sweetpi imports.
modules = require '../../lib/modules'
sensors = require "../../lib/sensors"

# ##The ClockBackend
class DevicePresentsBackend extends modules.Backend
  server: null
  config: null

  # The `init` function just registers the clock actuator.
  init: (@server, @config) =>
    session = ping.createSession()
    assert Array.isArray @config.devices
    for dc in config.devices
      assert dc.id?
      assert dc.name?
      assert dc.host? 
      device = new NetworkDevicePresents(dc.id, dc.name, dc.host, 
        (if dc.delay then dc.delay else 3000), session)
      server.registerSensor device

    #server.registerSensor(new NetworkDevicePresents config)

backend = new DevicePresentsBackend

# ##The Clock-Actuator
# Provides the time and time events for the rule module.
class NetworkDevicePresents extends sensors.Sensor
  config: null
  listener: []
  present: null
  interval: null

  constructor: (@id, @name, @host, @delay, @session) ->
    self = @
    self.interval = setInterval(self.ping, delay)

  getSensorValuesNames: ->
    "present"

  getSensorValue: (name)->
    self = @
    switch name
      when "present" then return self.present
      else throw new Error("Illegal sensor value name")

  isTrue: (id, predicate) ->
    self = @
    info = self.parsePredicate predicate
    if info? then return info.present is self.present
    else throw new Error "Sensor can not decide \"#{predicate}\"!"

  # Removes the notification for an with `notifyWhen` registered predicate. 
  cancelNotify: (id) ->
    self = @
    if self.listener[id]?
      delete self.listener

  # Registers notification for time events. 
  notifyWhen: (id, predicate, callback) ->
    self = @
    info = self.parsePredicate predicate
    if info?
      self.listener[id] =
        id: id
        callback: callback
        present: info.present
      return true
    return false

  notifyListener: ->
    self = @
    for id of self.listener
      l = self.listener[id]
      if l.present is self.present
        l.callback()

  ping: => 
    self = @
    @session.pingHost self.host, (error, target) ->
      if error
        if self.present isnt false
          self.present = false
          self.notifyListener()
      else
        if self.present isnt true  
          self.present = true
          self.notifyListener()

  parsePredicate: (predicate) ->
    self = @
    regExpString = '^(.+)\\s+is\\s+(not\\s+)?present$'
    matches = predicate.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      if deviceName is self.name or deviceName is self.id
        return info =
          deviceId: self.id
          present: (if matches[2]? then no else yes) 
    return null

# Export the Backendmodule.
module.exports = backend
# For testing...
module.exports.NetworkDevicePresents = NetworkDevicePresents