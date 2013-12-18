# 
spawn = require("child_process").spawn
convict = require "convict"
net = require "net"
EverSocket = require("eversocket").EverSocket
util = require 'util'
Q = require 'q'
assert = require 'cassert'

module.exports = (env) ->

  class PilightBackend extends env.plugins.Plugin
    framework: null
    config: null
    state: "unconnected"
    pilightConfig: null
    client: null
    stateCallbacks: []

    init: (@app, @framework, @config) =>
      conf = convict require("./pilight-config-shema")
      conf.load config
      conf.validate()
      @config = conf.get ""

      @client = new EverSocket(
        reconnectWait: 3000
        timeout: @config.timeout
        reconnectOnTimeout: true
      )

      @client.on "reconnect", =>
        env.logger.info "connected to pilight-daemon"
        @sendWelcome()

      @client.on "data", (data) =>
        for msg in data.toString().split "\n"
          if msg.length isnt 0
            @onReceive JSON.parse msg

      @client.on "end", =>
        @state = "unconnected"

      @client.on "error", (err) =>
        env.logger.error "Error on connection to pilight-daemon: #{err}"
        env.logger.debug err.stack
      
      @client.connect(
        @config.port,
        @config.host
      )
      return

    sendWelcome: ->
      @state = "welcome"
      @send { message: "client gui" }

    send: (jsonMsg) ->
      success = false
      if @state isnt "unconnected"
        env.logger.debug "pilight send: ", JSON.stringify(jsonMsg, null, " ")
        @client.write JSON.stringify(jsonMsg) + "\n", 'utf8'
        success = true
      return success

    sendState: (id, jsonMsg) ->
      deferred = Q.defer()

      onTimeout = => 
        for cb, i in @stateCallbacks
          if cb.id is id
            @stateCallbacks.splice i, 1
            deferred.reject "Request to pilight-daemon timeout"

      receiveTimeout = setTimeout onTimeout, @config.timeout

      @stateCallbacks.push
        id: id
        jsonMsg: jsonMsg
        deferred: deferred
        timeout: receiveTimeout

      success = @send jsonMsg
      unless success then deferred.recect "Could not send request to pilight-daemon"
      return deferred.promise

    onReceive: (jsonMsg) ->
      env.logger.debug "pilight received: ", JSON.stringify(jsonMsg, null, " ")
      switch @state
        when "welcome"
          if jsonMsg.message is "accept client"
            @state = "connected"
            @send { message: "request config" }
        else
          if jsonMsg.config?
            @onReceiveConfig jsonMsg.config
          else if jsonMsg.origin?
            # {
            #  "origin": "config",
            #  "type": 1,
            #  "devices": {
            #   "work": [
            #    "lampe"
            #   ]
            #  },
            #  "values": {
            #   "state": "off"
            #  }
            if jsonMsg.origin is 'config'
              for location, devices of jsonMsg.devices
                for device in devices
                  id = "pilight-#{location}-#{device}"
                  switch jsonMsg.type
                    when 1
                      @updateSwitch id, jsonMsg
                    when 3
                      @updateSensor id, jsonMsg
      return

    updateSwitch: (id, jsonMsg) ->
      actuator = @framework.getActuatorById id
      if actuator?
        actuator._setState if jsonMsg.values.state is 'on' then on else off
      for cb, i in @stateCallbacks
        if cb.id is id
          clearTimeout cb.timeout
          @stateCallbacks.splice i, 1
          cb.deferred.resolve()

    updateSensor: (id, jsonMsg) ->
      sensor = @framework.getSensorById id
      if sensor?
        sensor.setValues jsonMsg.values

    onReceiveConfig: (config) ->
      # iterate ´config = { living: { name: "Living", ... }, ...}´
      for location, devices of config
        #   location = "tv"
        #   device = { name: "Living", order: "1", protocol: [ "kaku_switch" ], ... }
        # iterate ´devices = { tv: { name: "TV", ...}, ... }´
        for device, deviceProbs of devices
          if typeof deviceProbs is "object"
            id = "pilight-#{location}-#{device}"
            deviceProbs.location = location
            deviceProbs.device = device
            switch deviceProbs.type
              when 1
                actuator = @framework.getActuatorById id
                if actuator?
                  if actuator instanceof PilightSwitch
                    actuator.updateFromPilightConfig deviceProbs
                  else
                    env.logger.error "actuator should be an PilightSwitch"
                else
                  # TODO: add to config.actuators
                  @framework.registerActuator new PilightSwitch id, deviceProbs
              when 3
                unless (@framework.getSensorById id)?
                  @framework.registerSensor new PilightTemperatureSensor id, deviceProbs
              else
                env.logger.warn "Unimplemented pilight device type: #{device.type}" 
      return

    createActuator: (config) =>
      return false

  backend = new PilightBackend

  class PilightSwitch extends env.actuators.PowerSwitch
    probs: null

    constructor: (@id, @probs) ->
      @updateFromPilightConfig(probs)

    # Run the pilight-send executable.
    changeStateTo: (state) ->
      if @state is state
        return Q.fcall => true

      jsonMsg =
        message: "send"
        code:
          location: @probs.location
          device: @probs.device
          state: if state then "on" else "off"

      return backend.sendState @id, jsonMsg

    updateFromPilightConfig: (@probs) ->
      assert probs?
      @name = probs.name
      @_setState (if probs.state is 'on' then on else off)


  class PilightTemperatureSensor extends env.sensors.TemperatureSensor
    name: null
    temperature: null
    humidity: null

    constructor: (@id, @probs) ->
      @name = probs.name
      @setValues
        temperature: @probs.temperature
        humidity: @probs.humidity

    setValues: (values) ->
      if values.temperature?
        @temperature = values.temperature/(@probs.settings.decimals*10)
        @emit "temperature", @temperature
      if values.humidity?
        @humidity = values.humidity/(@probs.settings.decimals*10)
        @emit "humidity", @humidity
      return

    getSensorValuesNames: ->
      names = []
      if @probs.settings.temperature is 1
        names.push 'temperature' 
      if @probs.settings.humidity is 1
        names.push 'humidity' 
      return names

    getSensorValue: (name) ->
      Q.fcall => 
        switch name
          when 'temperature' then return @temperature
          when 'humidity' then return @humidity
        throw new Error "Unknown sensor value name"

    canDecide: (predicate) ->
      return false

    isTrue: (id, predicate) ->
      throw new Error("no predicate implemented")

    notifyWhen: (id, predicate, callback) ->
      throw new Error("no predicates implemented")

    cancelNotify: (id) ->
      throw new Error("no predicates implemented")

  return backend