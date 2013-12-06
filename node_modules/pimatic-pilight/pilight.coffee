# 
spawn = require("child_process").spawn
convict = require "convict"
net = require "net"

module.exports = (env) ->

  class PilightBackend extends env.plugins.Plugin
    server: null
    config: null
    state: "unconnected"
    pilightConfig: null
    client: null

    init: (app, @server, @config) =>
      self = this
      conf = convict require("./pilight-config-shema")
      conf.load config
      conf.validate()

      self.client = net.connect(
        host: conf.get('host')
        port: conf.get('port')
      , -> #'connect' listener
        env.logger.info "connected to pilight-daemon"
        self.send { message: "client gui" }
        self.state = "welcome"
      )

      self.client.on "data", (data) ->
        for msg in data.toString().split "\n"
          if msg.length isnt 0
            self.onReceive JSON.parse msg

      self.client.on "end", ->
        self.state = "unconnected"

    send: (jsonMsg) ->
      self = this
      success = false
      if self.state isnt "unconnected"
        self.client.write JSON.stringify(jsonMsg) + "\n"
        success = true
      return success

    onReceive: (jsonMsg) ->
      self = this
      switch self.state
        when "welcome"
          if jsonMsg.message is "accept client"
            self.state = "connected"
            self.send { message: "request config" }
        else
          if jsonMsg.config?
            self.onReceiveConfig jsonMsg.config

    onReceiveConfig: (config) ->
      self = this
      # iterate ´config = { living: { name: "Living", ... }, ...}´
      for location, devices of config
        #   location = "tv"
        #   device = { name: "Living", order: "1", protocol: [ "kaku_switch" ], ... }
        # iterate ´devices = { tv: { name: "TV", ...}, ... }´
        for device, deviceProbs of devices
          if typeof deviceProbs is "object"
            if deviceProbs.protocol[0].match "_switch"
              deviceProbs.location = location
              deviceProbs.device = device
              self.server.registerActuator new PilightSwitch "#{location}-#{device}", deviceProbs
              console.log device, ": ", deviceProbs 

    createActuator: (config) =>
      return false

  backend = new PilightBackend

  class PilightSwitch extends env.actuators.PowerSwitch
    probs: null

    constructor: (@id, @probs) ->
      self = this
      self.name = probs.name

    # Run the pilight-send executable.
    changeStateTo: (state, resultCallbak) ->
      self = this
      if self.state is state then resultCallbak true

      jsonMsg =
        message: "send"
        code:
          location: self.probs.location
          device: self.probs.device
          state: if state then "on" else "off"

      success = backend.send jsonMsg

      self._setState(state) if success
      resultCallbak success

  return backend