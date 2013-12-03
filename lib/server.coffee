assert = require 'cassert'
fs = require "fs"
async = require 'async'

module.exports = (env) ->

  class Server extends require('events').EventEmitter
    configFile: null
    plugins: []
    actuators: []
    sensors: []
    ruleManager: null

    constructor: (@app, @config, @configFile) ->
      assert app?
      assert config?
      assert configFile?

      env.helper.checkConfig env, null, ->
        assert config instanceof Object
        assert Array.isArray config.plugins
        assert Array.isArray config.actuators
        assert Array.isArray config.rules

      @ruleManager = new env.rules.RuleManager this, @config.rules
      @pluginManager = new env.plugins.PluginManager this


    loadPlugins: (cb)->
      self = this
      async.mapSeries(self.config.plugins, (pConf, cb)->
        assert pConf?
        assert pConf instanceof Object
        assert pConf.plugin? and typeof pConf.plugin is "string" 

        env.logger.info "loading plugin: \"#{pConf.plugin}\"..."
        plugin = self.pluginManager.loadPlugin env, "pimatic-#{pConf.plugin}", (err, plugin) ->
          cb(err, {plugin: plugin, config: pConf})
      , (err, plugins) ->
        self.registerPlugin(p.plugin, p.config) for p in plugins
        cb(err)
      )


    registerPlugin: (plugin, config) ->
      assert plugin? and plugin instanceof env.plugins.Plugin
      assert config? and config instanceof Object

      @plugins.push {plugin: plugin, config: config}
      @emit "plugin", plugin

    registerActuator: (actuator) ->
      assert actuator?
      assert actuator instanceof env.actuators.Actuator
      assert actuator.name? and actuator.name.lenght isnt 0
      assert actuator.id? and actuator.id.lenght isnt 0

      if @actuators[actuator.id]?
        throw new assert.AssertionError("dublicate actuator id \"#{actuator.id}\"")

      env.logger.info "new actuator \"#{actuator.name}\"..."
      @actuators[actuator.id]=actuator
      @emit "actuator", actuator

    registerSensor: (sensor) ->
      assert sensor?
      assert sensor instanceof env.sensors.Sensor
      assert sensor.name? and sensor.name.lenght isnt 0
      assert sensor.id? and sensor.id.lenght isnt 0

      if @sensors[sensor.id]?
        throw new assert.AssertionError("dublicate sensor id \"#{sensor.id}\"")

      env.logger.info "new sensor \"#{sensor.name}\"..."
      @sensors[sensor.id]=sensor
      @emit "sensor", sensor

    loadActuators: ->
      for acConfig in @config.actuators
        found = false
        for plugin in @plugins
          if plugin.plugin.createActuator?
            found = plugin.plugin.createActuator acConfig
            if found then break
        unless found
          env.logger.warn "no plugin found for actuator \"#{acConfig.id}\"!"

    getActuatorById: (id) ->
      @actuators[id]

    init: ->
      self = this
      self.loadPlugins (err) ->
        if err then throw err

        for plugin in self.plugins
          try
            plugin.plugin.init(self.app, self, plugin.config)
          catch err
            env.logger.error "Could not initialize the plugin \"#{plugin.config.plugin}\": " +
              err.message
            env.logger.debug err.stack

        self.loadActuators()

        self.ruleManager.actionHandlers.push new env.actions.SwitchActionHandler
        self.ruleManager.actionHandlers.push new env.actions.LogActionHandler

        for rule in self.config.rules
          try
            self.ruleManager.addRuleByString(rule.id, rule.rule) 
          catch err
            env.logger.error "Could not parse rule \"#{rule.rule}\": " + err.message 
            env.logger.debug err.stack

        # Save rule updates to the config file:
        # 
        # * If a new rule was added then...
        self.ruleManager.on "add", (rule) ->
          # ...add it to the rules Array in the config.json file
          self.config.rules.push 
            id: rule.id
            rule: rule.string
          self.emit "config"
        # * If a rule was changed then...
        self.ruleManager.on "update", (rule) ->
          # ...change the rule with the right id in the config.json file
          self.config.rules = for r in self.config.rules 
            if r.id is rule.id then {id: rule.id, rule: rule.string}
            else r
          self.emit "config"
        # * If a rule was removed then
        self.ruleManager.on "remove", (rule) ->
          # ...Remove the rule with the right id in the config.json file
          self.config.rules = (r for r in self.config.rules when r.id isnt rule.id)
          self.emit "config"

        # Save the config on "config" event
        self.on "config", ->
        self.saveConfig()


    saveConfig: ->
      self = this
      fs.writeFile self.configFile, JSON.stringify(self.config, null, 2), (err) ->
        if err? then throw err
        else env.logger.info "config.json updated"