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
exec = require("child_process").exec
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


  getState: (callback) ->
    unless @_state?
      child = exec "#{backend.config.binary} -qng #{@config.outletUnit}", 
        (error, stdout, stderr) ->
          #console.log error
          console.log stderr if stderr.length isnt 0
          console.log stdout if stdout.length isnt 0
          stdout = stdout.trim()
          unless error?
            switch stdout
              when "1"
                @_state = on
              when "0"
                @_state = off
              else console.log "SispmctlSwitch: unknown state=\"#{stdout}\"!"
            callback error, @_state
    else callback null, @_state
      

  changeStateTo: (state, resultCallbak) ->
    thisClass = this
    if @state is state then resultCallbak true
    param = (if state then "-o" else "-f")
    param += " " + @config.outletUnit
    child = exec "#{backend.config.binary} #{param}", 
      (error, stdout, stderr) ->
        console.log stderr if stderr.length isnt 0
        console.log stdout if stdout.length isnt 0
        thisClass._setState(state) unless error?
        resultCallbak error

module.exports = backend