spawn = require("child_process").spawn
actuators = require "../../lib/actuators"
modules = require "../../lib/modules"

class Sispmctl extends modules.Backend
  server: null
  config: null

  init: (@server, @config) =>

  createActuator: (config) =>
    if config.class is "Sispmctl" 
      @server.registerActuator(new PowerOutletSispmctl config)
      return true
    return false

backend = new Sispmctl

class PowerOutletSispmctl extends actuators.PowerOutlet
  config: null

  constructor: (@config) ->
    #TODO: Check config!
    @name = config.name
    @id = config.id

  changeStateTo: (state, resultCallbak) ->
    thisClass = this
    if @state is state then resultCallbak true
    param = (if state then "-o" else "-f")
    param += " " + @config.outletUnit
    child = spawn backend.config.binary, [param]
    child.on "exit", (code) ->
      success = (code is 0)
      thisClass.state = state if success
      resultCallbak success

module.exports = backend