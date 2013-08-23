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
  _config: null

  constructor: (config) ->
    #TODO: Check config!
    @_config = config
    @name = config.name
    @id = config.id

  turnOn: (callback) ->
    console.log callback
    _this = @
    @_send on, (e) -> 
      _this._turnOn()
      callback e

  turnOff: (callback) ->
    _this = @
    @_send off, (e) -> 
      _this._turnOff()
      callback e

  #
  #* Turns a outlet-unit on or off.
  #
  _send: (state, resultCallbak) ->
    param = (if state then "-o" else "-f")
    param += " " + @_config.outletUnit
    child = spawn backend.config.binary, [param]
    child.on "exit", (code) ->
      success = (code is 0)
      resultCallbak success


module.exports = backend