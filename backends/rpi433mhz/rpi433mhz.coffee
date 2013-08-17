spawn = require("child_process").spawn
modules = require '../../lib/modules'
actors = require "../../lib/actors"

class Rpi433Backend extends modules.Backend
  server: null
  config: null

  init: (@server, @config) =>

  createActor: (config) =>
    if config.class is "Rpi433Mhz" 
      @server.registerActor(new Rpi433Mhz config)
      return true
    return false



backend = new Rpi433Backend

class Rpi433Mhz extends actors.PowerOutlet
  _config: null

  constructor: (config) ->
    #TODO: Check config!
    @_config = config
    @name = config.name
    @id = config.id

  turnOn: (callback) ->
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
  # Turns a outlet-unit on or off.
  #
  _send: (state, resultCallbak) ->
    onOff = (if state then "-t" else "-f")
    child = spawn backend.config.binary, ["-u " + @_config.outletUnit, "-i " + @_config.outletId, onOff]
    child.on "exit", (code) ->
      success = (code is 0)
      resultCallbak success


module.exports = backend