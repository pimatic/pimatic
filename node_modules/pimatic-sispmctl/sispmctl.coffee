# 
exec = require("child_process").exec
convict = require "convict"

module.exports = (env) ->

  class Sispmctl extends env.plugins.Plugin
    server: null
    config: null

    init: (app, @server, @config) =>
      conf = convict require("./sispmctl-config-shema")
      conf.load config
      conf.validate()

    createActuator: (config) =>
      if config.class is "SispmctlSwitch" 
        @server.registerActuator(new SispmctlSwitch config)
        return true
      return false

  backend = new Sispmctl

  class SispmctlSwitch extends env.actuators.PowerSwitch
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
            env.logger.error stderr if stderr.length isnt 0
            stdout = stdout.trim()
            unless error?
              switch stdout
                when "1"
                  @_state = on
                when "0"
                  @_state = off
                else env.logger.error "SispmctlSwitch: unknown state=\"#{stdout}\"!"
            callback error, @_state
      else callback null, @_state
        

    changeStateTo: (state, resultCallbak) ->
      thisClass = this
      if @state is state then resultCallbak true
      param = (if state then "-o" else "-f")
      param += " " + @config.outletUnit
      child = exec "#{backend.config.binary} #{param}", 
        (error, stdout, stderr) ->
          env.logger.error stderr if stderr.length isnt 0
          thisClass._setState(state) unless error?
          resultCallbak error

  return backend