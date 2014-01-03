# 
convict = require "convict"
Q = require 'q'
exec = Q.denodeify(require("child_process").exec)

module.exports = (env) ->

  class Sispmctl extends env.plugins.Plugin
    server: null
    config: null

    init: (app, @server, config) =>
      self = this
      conf = convict require("./sispmctl-config-shema")
      conf.load config
      conf.validate()
      self.config = conf.get ""
      self.checkBinary()

    checkBinary: ->
      self = this
      exec("#{self.config.binary} -v").catch( (error) ->
        if error.message.match "not found"
          env.logger.error "sispmctl binary not found. Check your config!"
      ).done()


    createActuator: (config) =>
      if config.class is "SispmctlSwitch" 
        @server.registerActuator(new SispmctlSwitch config)
        return true
      return false

  backend = new Sispmctl

  class SispmctlSwitch extends env.actuators.PowerSwitch
    config: null

    constructor: (config) ->
      self = this
      conf = convict require("./actuator-config-shema")
      conf.load config
      conf.validate()
      self.config = conf.get ""

      self.name = config.name
      self.id = config.id

    getState: () ->
      self = this
      unless self._state?
        # Built the sispmctrl command to get the outlet status
        command = "#{backend.config.binary} -q -n" # quiet and numerical
        command += " -d #{self.config.device}" # select the device
        command += " -g #{self.config.outletUnit}" # get status of the outlet
        # and execue it.
        return exec(command).then( (streams) ->
          stdout = streams[0]
          stderr = streams[1]
          stdout = stdout.trim()
          switch stdout
            when "1"
              return self._state = on
            when "0"
              return self._state = off
            else 
              env.logger.debug stderr
              throw new Error "SispmctlSwitch: unknown state=\"#{stdout}\"!"
          )
      else Q.fcall -> self._state
        

    changeStateTo: (state) ->
      self = this
      if self.state is state then return Q.fcall -> true
      # Built the sispmctrl command
      command = "#{backend.config.binary}"
      command += " -d #{self.config.device}" # select the device
      command += " " + (if state then "-o" else "-f") # do on or off
      command += " " + self.config.outletUnit # select the outlet
      # and execue it.
      return exec(command).then( (streams) ->
        stdout = streams[0]
        stderr = streams[1]
        env.logger.debug stderr if stderr.length isnt 0
        self._setState(state)
      )

  return backend