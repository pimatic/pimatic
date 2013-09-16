assert = require 'cassert'
helper = require './helper'
actuators = require './actuators'
sensors = require './sensors'
rules = require './rules'
modules = require './modules'
logger = require "./logger"
fs = require "fs"

class Server extends require('events').EventEmitter
  frontends: []
  backends: []
  actuators: []
  sensors: []
  ruleManager: null

  constructor: (@app, @config) ->
    assert app?
    assert config?

    helper.checkConfig null, ->
      assert config instanceof Object
      assert Array.isArray config.frontends
      assert Array.isArray config.backends
      assert Array.isArray config.actuators
      assert Array.isArray config.rules

    @ruleManager = new rules.RuleManager this, @config.rules
    @loadBackends()
    @loadFrontends()


  loadBackends: ->
    for beConf in @config.backends
      assert beConf?
      assert beConf instanceof Object
      assert beConf.module? and typeof beConf.module is "string" 

      logger.info "loading backend: \"#{beConf.module}\"..."
      be = require "../backends/" + beConf.module
      @registerBackend be, beConf

  loadFrontends: ->
    for feConf in @config.frontends
      assert feConf?
      assert feConf instanceof Object
      assert feConf.module? and typeof feConf.module is "string" 

      logger.info "loading frontend: \"#{feConf.module}\"..."
      fe = require "../frontends/" + feConf.module
      @registerFrontend fe, feConf

  registerFrontend: (frontend, config) ->
    assert frontend? and frontend instanceof modules.Frontend
    assert config? and config instanceof Object

    @frontends.push {module: frontend, config: config}
    @emit "frontend", frontend

  registerBackend: (backend, config) ->
    assert backend? and backend instanceof modules.Backend
    assert config? and config instanceof Object

    @backends.push {module: backend, config: config}
    @emit "backend", backend

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
      for be in @backends
        found = be.module.createActuator acConfig
        if found then break
      unless found
        console.warn "no backend found for actuator \"#{acConfig.id}\"!"

  getActuatorById: (id) ->
    @actuators[id]

  init: ->
    self = @
    b.module.init @, b.config for b in @backends
    @loadActuators()
    f.module.init @app, @, f.config for f in @frontends
    actions = require './actions'
    @ruleManager.actionHandlers.push actions(this)
    for rule in @config.rules
      @ruleManager.addRuleByString rule.id, rule.rule

    self.ruleManager.on "add", (rule) ->
      self.config.rules.push 
        id: rule.id
        rule: rule.string
      self.emit "config"
    self.ruleManager.on "update", (rule) ->
      for r, i in self.config.rules
        if r.id is rule.id
          self.config.rules[i] = 
            id: rule.id,
            rule: rule.string
          break
      self.emit "config"

    self.on "config", ->
      self.saveConfig()


  saveConfig: ->
    fs.writeFile "config.json", JSON.stringify(@config, null, 2), (err) ->
      if err? then throw err
      else logger.info "config.json updated"
 module.exports = Server