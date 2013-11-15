# ##Dependencies
convict = require "convict"
util = require 'util'
ping = require "net-ping"
assert = require 'cassert'
Tail = require('tail').Tail

module.exports = (env) ->

  # ##The LogNotificationsBackend
  class LogNotificationsBackend extends env.plugins.Plugin
    server: null
    config: null

    # The `init` function just registers the clock actuator.
    init: (app, @server, @config) =>
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
        @tail.removeListener 'data', self.listener[id]
        delete self.listener[id]

    notifyWhen: (id, predicate, callback) ->
      self = @
      found = false
      for line in @lines
        do (line) ->
          if not found and predicate.match(new RegExp(line.predicate))
            regex = new RegExp(line.match)
            lineCallback = (data) ->
              if data.match regex
                callback()
            self.tail.on 'line', lineCallback
            self.listener[id] = lineCallback
            found = true
      return found

  # For testing...
  @LogNotificationsBackend = LogNotificationsBackend
  # Export the Backendmodule.
  return backend