# #The pilight backend
# Backend for the [pilight library](https://github.com/pilight/pilight) to control 433Mhz switches 
# and dimmers and get informations from 433Mhz weather stations. See the project page for a list of 
# supported devices.
# ##Configuration
# You can load the backend by editing your `config.json` to include:
# 
#     { 
#        "module": "pilight"
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
#       "class": "PilightSwitch", 
#       "name": "Lamp",
#       "outletUnit": 0,
#       "outletId": 123456 
#     }
# 
# For actuator configuration options see the 
# [actuator-config-shema.coffee](actuator-config-shema.html) file.

# 
spawn = require("child_process").spawn
convict = require "convict"
modules = require '../../lib/modules'
actuators = require "../../lib/actuators"


class PilightBackend extends modules.Backend
  server: null
  config: null

  init: (@server, @config) =>
    conf = convict require("./backend-config-shema")
    conf.load config
    conf.validate()

  createActuator: (config) =>
    if config.class is "PilightSwitch" 
      @server.registerActuator(new PilightSwitch config)
      return true
    return false



backend = new PilightBackend

class PilightSwitch extends actuators.PowerSwitch
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

module.exports = backend