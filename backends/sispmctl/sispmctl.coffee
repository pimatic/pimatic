# #The sispmctl backend
# Backend for the [SIS-PM Control for Linux aka sispmct](http://sispmctl.sourceforge.net/) 
# application that can control GEMBIRD (m)SiS-PM device, witch are USB controled multiple socket.
# ##Configuration
# You can load the backend by editing your `config.json` to include:
# 
#     { 
#        "module": "sispmctl"
#     }
# 
# in the `backend` section. For all configuration options see 
# [backend-config-shema](backend-config-shema.html)
# 
# Actuators can be added bei adding them to the `actuators` section in the config file.
# Set the `class` attribute to `PilightOutlet`. For example:
# 
#     { 
#       "id": "light",
#       "class": "SispmctlSwitch", 
#       "name": "Lamp",
#       "outletId": 1 
#     }
# 
# For actuator configuration options see the 
# [actuator-config-shema.coffee](actuator-config-shema.html) file.

# 
spawn = require("child_process").spawn
actuators = require "../../lib/actuators"
modules = require "../../lib/modules"
convict = require "convict"

class Sispmctl extends modules.Backend
  server: null
  config: null

  init: (@server, @config) =>
    conf = convict require("./backend-config-shema")
    conf.load config
    conf.validate()

  createActuator: (config) =>
    if config.class is "SispmctlSwitch" 
      @server.registerActuator(new SispmctlSwitch config)
      return true
    return false

backend = new Sispmctl

class SispmctlSwitch extends actuators.PowerSwitch
  config: null

  constructor: (@config) ->
    conf = convict require("./actuator-config-shema")
    conf.load config
    conf.validate()

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