spawn = require("child_process").spawn
convict = require "convict"
modules = require '../../lib/modules'
actors = require "../../lib/actors"


class PilightBackend extends modules.Backend
  server: null
  config: null

  init: (@server, @config) =>
    conf = convict require("./backend-config-shema")
    conf.load config
    conf.validate()

  createActor: (config) =>
    if config.class is "PilighOutlet" 
      @server.registerActor(new PilighOutlet config)
      return true
    return false



backend = new PilightBackend

class PilighOutlet extends actors.PowerOutlet
  _config: null

  constructor: (config) ->
    conf = convict require("./actor-config-shema")
    conf.load config
    conf.validate()
    
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
    child = spawn backend.config.binary, [
      "-p " + @_config.protocol
      "-u " + @_config.outletUnit, 
      "-i " + @_config.outletId, 
      onOff]
    child.on "exit", (code) ->
      success = (code is 0)
      resultCallbak success


module.exports = backend