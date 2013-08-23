should = require 'should'
assert = require 'assert'
helper = require './helper'
actuators = require './actuators'
sensors = require './sensors'
rules = require './rules'
modules = require './modules'

class Server extends require('events').EventEmitter
  frontends: []
  backends: []
  actuators: []
  sensors: []
  ruleManager: null

  constructor: (app, config) ->
    should.exist app
    should.exist config
    helper.checkConfig null, ->
      config.should.be.a 'object', "config is no object?"
      config.should.have.property('frontends').instanceOf Array, "frontends should be an array"
      config.should.have.property('backends').instanceOf Array, "backends should be an array"
      config.should.have.property('actuators').instanceOf Array, "actuators should be an array"

    @app = app
    @config = config
    @ruleManager = new rules.RuleManager this
    @loadBackends()
    @loadFrontends()


  loadBackends: ->
    for beConf in @config.backends
      should.exist beConf
      beConf.should.be.a 'object'
      beConf.should.have.property 'module'

      console.log "loading backend: \"#{beConf.module}\"..."
      be = require "../backends/" + beConf.module
      @registerBackend be, beConf

  loadFrontends: ->
    for feConf in @config.frontends
      should.exist feConf
      feConf.should.be.a 'object'
      feConf.should.have.property 'module'

      console.log "loading frontend: \"#{feConf.module}\"..."
      fe = require "../frontends/" + feConf.module
      @registerFrontend fe, feConf

  registerFrontend: (frontend, config) ->
    should.exist frontend
    should.exist config
    frontend.should.be.instanceOf modules.Frontend

    config.should.be.a 'object'
    @frontends.push {module: frontend, config: config}
    @emit "frontend", frontend

  registerBackend: (backend, config) ->
    should.exist backend
    backend.should.be.instanceOf modules.Backend

    @backends.push {module: backend, config: config}
    @emit "backend", backend

  registerActuator: (actuator) ->
    should.exist actuator
    actuator.should.be.instanceOf actuators.Actuator
    actuator.should.have.property("name").not.empty
    actuator.should.have.property("id").not.empty
    if @actuators[actuator.id]?
      throw new assert.AssertionError("dublicate actuator id \"#{actuator.id}\"")

    console.log "new actuator \"#{actuator.name}\"..."
    @actuators[actuator.id]=actuator
    @emit "actuator", actuator

  registerSensor: (sensor) ->
    should.exist sensor
    sensor.should.be.instanceOf sensors.Sensor
    sensor.should.have.property("name").not.empty
    sensor.should.have.property("id").not.empty
    if @sensors[sensor.id]?
      throw new assert.AssertionError("dublicate sensor id \"#{sensor.id}\"")

    console.log "new sensor \"#{sensor.name}\"..."
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
    b.module.init @, b.config for b in @backends
    @loadActuators()
    f.module.init @app, @, f.config for f in @frontends
    actions = require './actions'
    @ruleManager.actionHandlers.push actions(this)

 module.exports = Server