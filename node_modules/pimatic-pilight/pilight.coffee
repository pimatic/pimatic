# 
spawn = require("child_process").spawn
convict = require "convict"
net = require "net"
EverSocket = require("eversocket").EverSocket
util = require 'util'

module.exports = (env) ->

  class PilightBackend extends env.plugins.Plugin
    server: null
    config: null
    state: "unconnected"
    pilightConfig: null
    client: null
    stateCallbacks: []

    init: (@app, @server, @config) =>

      self = this
      conf = convict require("./pilight-config-shema")
      conf.load config
      conf.validate()
      self.config = conf.get ""

      self.client = new EverSocket(
        reconnectWait: 3000 # wait 100ms after close event before reconnecting
        timeout: 100 # set the idle timeout to 100ms
        reconnectOnTimeout: true # reconnect if the connection is idle
      )

      self.client.on "reconnect", ->
        env.logger.info "connected to pilight-daemon"
        self.sendWelcome()

      self.client.on "data", (data) ->
        for msg in data.toString().split "\n"
          if msg.length isnt 0
            self.onReceive JSON.parse msg

      self.client.on "end", ->
        self.state = "unconnected"

      self.client.on "error", (err) ->
        env.logger.error "Error on connection to pilight-daemon: #{err}"
        env.logger.debug err.stack
      self.connect()


    connect: () ->
      self = this
      self.client.connect(
        self.config.port,
        self.config.host
      # , -> #'connect' listener
      #   env.logger.info "connected to pilight-daemon"
      #   self.sendWelcome()
      )

    sendWelcome: ->
      self = this
      self.state = "welcome"
      self.send { message: "client gui" }

    send: (jsonMsg) ->
      self = this
      success = false
      if self.state isnt "unconnected"
        env.logger.debug "pilight send: ", JSON.stringify(jsonMsg, null, " ")
        self.client.write JSON.stringify(jsonMsg) + "\n", 'utf8'
        success = true
      return success

    sendState: (jsonMsg, callback) ->
      self = this

      receiveTimeout = setTimeout( -> 
        for cb, i in self.stateCallbacks
          if cb.jsonMsg.code.location is jsonMsg.code.location and 
             cb.jsonMsg.code.devie is jsonMsg.code.device
            self.stateCallbacks.splice i, 1
        callback false
      , 3000)

      self.stateCallbacks.push
        jsonMsg: jsonMsg
        callback: callback
        timeout: receiveTimeout

      success = self.send jsonMsg
      return success

    onReceive: (jsonMsg) ->
      self = this
      env.logger.debug "pilight received: ", JSON.stringify(jsonMsg, null, " ")
      switch self.state
        when "welcome"
          if jsonMsg.message is "accept client"
            self.state = "connected"
            self.send { message: "request config" }
        else
          if jsonMsg.config?
            self.onReceiveConfig jsonMsg.config
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
                  id = "#{location}-#{device}"
                  actuator = self.server.getActuatorById id
                  env.logger.info id
                  if actuator?
                    actuator._setState if jsonMsg.values.state is 'on' then on else off
                  for cb, i in self.stateCallbacks
                    if cb.jsonMsg.code.location is location and 
                       cb.jsonMsg.code.device is device
                      clearTimeout cb.timeout
                      self.stateCallbacks.splice i, 1
                      cb.callback true

    onReceiveConfig: (config) ->
      self = this
      # iterate ´config = { living: { name: "Living", ... }, ...}´
      for location, devices of config
        #   location = "tv"
        #   device = { name: "Living", order: "1", protocol: [ "kaku_switch" ], ... }
        # iterate ´devices = { tv: { name: "TV", ...}, ... }´
        for device, deviceProbs of devices
          if typeof deviceProbs is "object"
            id = "#{location}-#{device}"
            unless (self.server.getActuatorById id)?
              if deviceProbs.protocol[0].match "_switch"
                deviceProbs.location = location
                deviceProbs.device = device
                self.server.registerActuator new PilightSwitch id, deviceProbs

    createActuator: (config) =>
      return false

  backend = new PilightBackend

  class PilightSwitch extends env.actuators.PowerSwitch
    probs: null

    constructor: (@id, @probs) ->
      self = this
      self.name = probs.name

    # Run the pilight-send executable.
    changeStateTo: (state, resultCallback) ->
      self = this
      if self.state is state
        resultCallback true
        return

      jsonMsg =
        message: "send"
        code:
          location: self.probs.location
          device: self.probs.device
          state: if state then "on" else "off"

      success = backend.sendState jsonMsg, resultCallback

      unless success then resultCallback false

  return backend