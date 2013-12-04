# 
spawn = require("child_process").spawn
convict = require "convict"
net = require "net"

module.exports = (env) ->

  class PilightBackend extends env.plugins.Plugin
    server: null
    config: null

    init: (app, @server, @config) =>
      conf = convict require("./pilight-config-shema")
      conf.load config
      conf.validate()


      client = net.connect(
        host: conf.get('host')
        port: conf.get('port')
      , -> #'connect' listener
        env.logger.info "connected to pilight-daemon"
        client.write JSON.stringify { message: "client gui"}
      )
      
      client.on "data", (data) ->
        console.log data.toString()
        client.end()

      client.on "end", ->
        console.log "client disconnected"



    createActuator: (config) =>
      if config.class is "PilightSwitch" 
        @server.registerActuator(new PilightSwitch config)
        return true
      return false

  backend = new PilightBackend

  class PilightSwitch extends env.actuators.PowerSwitch
    config: null

    constructor: (@config) ->
      conf = convict require("./actuator-config-shema")
      conf.load config
      conf.validate()
      
      @name = config.name
      @id = config.id

    # Run the pilight-send executable.
    changeState: (state, resultCallbak) ->
      thisClass = this
      if @state is state then resultCallbak true
      onOff = (if state then "-t" else "-f")
      child = spawn backend.config.binary, [
        "-p " + @config.protocol
        "-u " + @config.outletUnit, 
        "-i " + @config.outletId, 
        onOff
      ]
      child.on "exit", (code) ->
        success = (code is 0)
        thisClass._setState(state) if success
        resultCallbak success

  return backend