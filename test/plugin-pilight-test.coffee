assert = require "cassert"
proxyquire = require 'proxyquire'
Q = require 'q'

describe "pimatic-pilight", ->

    # Setup the environment
  env =
    helper: require '../lib/helper'
    logger: require '../lib/logger'
    actuators: require '../lib/actuators'
    sensors: require '../lib/sensors'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'

  connected = false

  class EverSocketDummy extends require('events').EventEmitter
    connect: (port, host) -> 
      connected = true
      assert host?
      assert port? and not isNaN port


  pilightPluginWrapper = proxyquire 'pimatic-pilight',
    eversocket: 
      EverSocket: EverSocketDummy

  class FrameworkDummy

  pilightPlugin = pilightPluginWrapper env

  framework = new FrameworkDummy
  actuator = null

  describe '#init()', ->

    it "should connect", ->
      pilightPlugin.init null, framework, timeout: 1000
      assert connected

    it "should send welcome", ->
      gotData = false
      pilightPlugin.client.write = (data) ->
        gotData = true
        msg = JSON.parse data
        assert msg.message is "client gui" 

      pilightPlugin.client.emit "reconnect"
      assert gotData
      assert pilightPlugin.state is "welcome"

  describe "#onReceive()", ->

    it "should request config", ->

      gotData = false
      pilightPlugin.client.write = (data) ->
        gotData = true
        msg = JSON.parse data
        assert msg.message is "request config" 

      pilightPlugin.client.emit 'data', JSON.stringify(
        message: "accept client"
      ) + "\n"

      assert gotData
      assert pilightPlugin.state is "connected"

    it "should add actuator", ->
      sampleConfigMsg =
        config:
          living:
            name: "Living"
            order: 1
            bookshelve:
              type: 1
              name: "Book Shelve Light"
              protocol: ["kaku_switch"]
              id: [
                id: 1234
                unit: 0
              ]
              state: "off"

        version: [
          "2.0"
          "2.0"
        ]

      getActuatorByIdCalled = false
      framework.getActuatorById = (id) ->
        assert id is "pilight-living-bookshelve"
        getActuatorByIdCalled = true
        return null

      registerActuatorCalled = false
      framework.registerActuator = (a) ->
        registerActuatorCalled = true
        assert a?
        actuator = a

      addActuatorToConfigCalled = false
      framework.addActuatorToConfig = (config) ->
        assert config?
        addActuatorToConfigCalled = true

      framework.isActuatorInConfig = -> false
      framework.updateActuatorConfig = (config) -> 
        assert config.id is "pilight-living-bookshelve"
        assert config.class is "PilightSwitch"

      pilightPlugin.client.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

      assert getActuatorByIdCalled
      assert registerActuatorCalled
      assert addActuatorToConfigCalled
      assert actuator?

  describe "#turnOn()", ->

    it "should send turnOn", (finish)->
      this.timeout 1000

      framework.getActuatorById = (id) ->
        assert id is actuator.id
        return actuator

      gotData = false
      pilightPlugin.client.write = (data) ->
        gotData = true
        msg = JSON.parse data
        assert msg?
        assert msg.message is 'send'
        assert msg.code?
        assert msg.code.location is 'living'
        assert msg.code.device is 'bookshelve'

      setTimeout( () ->
        msg = 
          origin: "config"
          type: 1
          devices:
            living: ["bookshelve"]
          values:
            state: "on"
        pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
      , 200)

      actuator.turnOn().then( ->
        assert gotData
        finish()
      ).done()

    it "turnOn should timeout", (finish) ->
      this.timeout 5000
      pilightPlugin.config.timeout = 200

      gotData = false
      pilightPlugin.client.write = (data) ->
        gotData = true
        msg = JSON.parse data
        assert msg?
        assert msg.message is 'send'
        assert msg.code?
        assert msg.code.location is 'living'
        assert msg.code.device is 'bookshelve'

      actuator.turnOn().then( -> 
        assert false
      ).catch( (error) ->
        assert error? 
        finish() 
      ).done()
