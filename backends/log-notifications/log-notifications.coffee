# #The log notification backend
# ##Providided predicates
# Add your device to the backend config:
# 
#     { 
#       "module": "log-notifications",
#       "logs": [
#         {
#           "file": "/var/log/gmediarender",
#           "lines": [
#             {
#               "match": "TransportState: PLAYING",
#               "predicate": "music starts"
#             },
#             {
#               "match": "TransportState: STOPPED",
#               "predicate": "music stops"
#             }
#           ]
#         }
#       ]
#     }
# 
# Then you can use the predicates defined in your config
# 

# ##Dependencies
convict = require "convict"
util = require 'util'
ping = require "net-ping"
assert = require 'cassert'
Tail = require('tail').Tail
# * sweetpi imports.
modules = require '../../lib/modules'
sensors = require "../../lib/sensors"

# ##The LogNotificationsBackend
class LogNotificationsBackend extends modules.Backend
  server: null
  config: null

  # The `init` function just registers the clock actuator.
  init: (@server, @config) =>
    assert Array.isArray @config.logs
    for log in config.logs
      watcher = new LogWatcher("logwatcher-#{log.file}", log.file, log.lines)
      server.registerSensor watcher

backend = new LogNotificationsBackend

# ##LogWatcher Sensor
class LogWatcher extends sensors.Sensor
  listener: []
  name: "log-watcher"

  constructor: (@id, @file, @lines) ->
    self = @
    @tail = new Tail(file)


  getSensorValue: (name)->
    self = @
    throw new Error("Illegal sensor value name")

  isTrue: (id, predicate) ->
    self = @
    return false

  # Removes the notification for an with `notifyWhen` registered predicate. 
  cancelNotify: (id) ->
    self = @
    if self.listener[id]?
      @tail.removeListener self.listener[id]
      delete self.listener[id]

  notifyWhen: (id, predicate, callback) ->
    self = @
    for line in @lines
      do (line) ->
        if predicate.match(new RegExp(line.predicate))
          regex = new RegExp(line.match)
          lineCallback = (data) ->
            if data.match regex
              callback()
          tail.on 'line', lineCallback
          self.listener[id] = lineCallback
          return true
    return false




# Export the Backendmodule.
module.exports = backend
# For testing...
module.exports.LogNotificationsBackend = LogNotificationsBackend