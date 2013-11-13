assert = require 'cassert'
helper = require './helper'
actuators = require './actuators'
sensors = require './sensors'
rules = require './rules'
plugins = require './plugins'
logger = require "./logger"
fs = require "fs"

class Server extends require('events').EventEmitter
  plugins: []
  actuators: []
  sensors: []
  ruleManager: null

  constructor: (@app, @config) ->
    assert app?
    assert config?

    helper.checkConfig null, ->
      assert config instanceof Object
      assert Array.isArray config.plugins
      assert Array.isArray config.actuators
      assert Array.isArray config.rules

    @ruleManager = new rules.RuleManager this, @config.rules
    @loadPlugins()


  loadPlugins: ->
    for pConf in @config.plugins
      assert pConf?
      assert pConf instanceof Object
      assert pConf.plugin? and typeof pConf.plugin is "string" 

      logger.info "loading plugin: \"#{pConf.plugin}\"..."
      plugin = require "sweetpi-#{pConf.plugin}"
      @registerPlugin plugin, pConf

  registerPlugin: (plugin, config) ->
    assert plugin? and plugin instanceof plugins.Plugin
    assert config? and config instanceof Object

    @plugins.push {plugin: plugin, config: config}
    @emit "plugin", plugin

  registerActuator: (actuator) ->
    assert actuator?
    assert actuator instanceof actuators.Actuator
    assert actuator.name? and actuator.name.lenght isnt 0
    assert actuator.id? and actuator.id.lenght isnt 0

    if @actuators[actuator.id]?
      throw new assert.AssertionError("dublicate actuator id \"#{actuator.id}\"")

    logger.info "new actuator \"#{actuator.name}\"..."
    @actuators[actuator.id]=actuator
    @emit "actuator", actuator

  registerSensor: (sensor) ->
    assert sensor?
    assert sensor instanceof sensors.Sensor
    assert sensor.name? and sensor.name.lenght isnt 0
    assert sensor.id? and sensor.id.lenght isnt 0

    if @sensors[sensor.id]?
      throw new assert.AssertionError("dublicate sensor id \"#{sensor.id}\"")

    logger.info "new sensor \"#{sensor.name}\"..."
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
        logger.warn "no plugin found for actuator \"#{acConfig.id}\"!"

  getActuatorById: (id) ->
    @actuators[id]

  init: ->
    self = @
    plugin.plugin.init(self.app, self, plugin.config) for plugin in self.plugins
    self.loadActuators()
    actions = require './actions'
    self.ruleManager.actionHandlers.push actions(this)
    self.ruleManager.addRuleByString(rule.id, rule.rule) for rule in self.config.rules

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
    fs.writeFile "config.json", JSON.stringify(@config, null, 2), (err) ->
      if err? then throw err
      else logger.info "config.json updated"

 module.exports = Server