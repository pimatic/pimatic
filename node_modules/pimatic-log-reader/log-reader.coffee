# ##Dependencies
convict = require "convict"
util = require 'util'
assert = require 'cassert'
Tail = require('tail').Tail
Q = require 'q'
assert = require 'cassert'

module.exports = (env) ->

  # ##The LogReaderPlugin
  class LogReaderPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) ->

    createSensor: (config) ->
      switch config.class
        when 'LogWatcher'
          assert config.name?
          assert config.id?
          watcher = new LogWatcher(config)
          @framework.registerSensor watcher
          return true
        else
          return false

  plugin = new LogReaderPlugin

  # ##LogWatcher Sensor
  class LogWatcher extends env.sensors.Sensor
    listener: []

    constructor: (@config) ->
      @id = config.id
      @name = config.name
      @tail = new Tail(config.file)
      @states = {}

      # initialise all states with unknown
      for name in @config.states
        @states[name] = 'unknown'

      # On ervery new line in the log file
      @tail.on 'line', (data) =>
        # check all lines in config
        for line in @config.lines
          # for a match.
          if data.match(new RegExp line.match)
            # If a match occures then emit a "match"-event.
            @emit 'match', line, data
        return

      # When a match event occures
      @on 'match', (line, data) =>
        # then check for each state in the config
        for state in @config.states
          # if the state is registed for the log line.
          if state of line
            # When a value for the state is define, then set the value
            # and emit the event.
            @states[state] = line[state]
            @emit state, line[state]

        for listener in @listener
          if line.match is listener.match
            listener.callback()
        return


    getSensorValuesNames: ->
      return @config.states

    getSensorValue: (name)->
      if name in @config.states
        return Q.fcall => @states[name]
      throw new Error("Illegal sensor value name")

    isTrue: (id, predicate) ->
      return Q.fcall -> false

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      if @listener[id]?
        delete @listener[id]

    _getLineWithPredicate: (predicate) ->
      for line in @config.lines
        if line.predicate? and predicate.match(new RegExp(line.predicate))
          return line
      return null

    canDecide: (predicate) ->
      line = @_getLineWithPredicate predicate
      return line?

    notifyWhen: (id, predicate, callback) ->
      line = @_getLineWithPredicate predicate
      unless line?
        throw new Error 'Can not decide the predicate!'

      @listener[id] =
        match: line.match
        callback: callback



  # For testing...
  @LogReaderPlugin = LogReaderPlugin
  # Export the plugin.
  return plugin