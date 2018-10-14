assert = require "cassert"
Promise = require 'bluebird'
i18n = require 'i18n-pimatic'
events = require 'events'
M = require '../lib/matcher'
_ = require 'lodash'

i18n.configure(
  locales:['en', 'de']
  directory: __dirname + '/../locales'
  defaultLocale: 'en'
)

env = require('../startup').env

createDummyParseContext = ->
  variables = {}
  functions = {}
  return M.createParseContext(variables, functions)

describe "SwitchActionHandler", ->

  frameworkDummy =
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  switchActionProvider = new env.actions.SwitchActionProvider frameworkDummy

  class DummySwitch extends env.devices.SwitchActuator
    id: 'dummy-switch-id'
    name: 'dummy switch'

  dummySwitch = new DummySwitch()
  frameworkDummy.deviceManager.devices['dummy-switch-id'] = dummySwitch

  describe "#parseAction()", ->
    turnOnCalled = false
    turnOffCalled = false

    beforeEach ->
      turnOnCalled = false
      dummySwitch.turnOn = ->
        turnOnCalled = true
        return Promise.resolve true

      turnOffCalled = false
      dummySwitch.turnOff = ->
        turnOffCalled = true
        return Promise.resolve true

    validRulePrefixes = [
      'turn the dummy switch'
      'turn dummy switch'
      'switch the dummy switch'
      'switch dummy switch'
    ]

    for rulePrefix in validRulePrefixes
      do (rulePrefix) ->

        ruleWithOn = rulePrefix + ' on'
        it "should parse: #{ruleWithOn}", (finish) ->
          context = createDummyParseContext()
          result = switchActionProvider.parseAction(ruleWithOn, context)
          assert result?
          assert result.token is ruleWithOn
          assert result.nextInput is ""
          assert result.actionHandler?
          result.actionHandler.executeAction(false).then( (message) ->
            assert turnOnCalled
            assert message is "turned dummy switch on"
            finish()
          ).done()

        ruleWithOff = rulePrefix + ' off'
        it "should execute: #{ruleWithOff}", (finish) ->
          context = createDummyParseContext()
          result = switchActionProvider.parseAction(ruleWithOff, context)
          assert result?
          assert result.token is ruleWithOff
          assert result.nextInput is ""
          assert result.actionHandler?
          result.actionHandler.executeAction(false).then( (message) ->
            assert turnOffCalled
            assert message is "turned dummy switch off"
            finish()
          ).done()

    it "should execute: turn on the dummy switch", (finish) ->
      context = createDummyParseContext()
      result = switchActionProvider.parseAction("turn on the dummy switch", context)
      assert result?
      assert result.token is "turn on the dummy switch"
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert turnOnCalled
        assert message is "turned dummy switch on"
        finish()
      ).done()

    it 'should not execute: invalid-id on', ->
      context = createDummyParseContext()
      result = switchActionProvider.parseAction("invalid-id on", context)
      assert not result?
      assert not turnOnCalled

    it 'should not execute: another dummy switch on', ->
      context = createDummyParseContext()
      result = switchActionProvider.parseAction("another dummy switch on", context)
      assert not result?
      assert not turnOnCalled

describe "ShutterActionHandler", ->

  frameworkDummy =
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  shutterActionProvider = new env.actions.ShutterActionProvider frameworkDummy
  stopShutterActionProvider = new env.actions.StopShutterActionProvider frameworkDummy

  class Shutter extends env.devices.ShutterController
    id: 'shutter-id'
    name: 'shutter'

    moveToPosition: () -> Promise.resolve()

  shutterDevice = new Shutter()
  frameworkDummy.deviceManager.devices['dummy-switch-id'] = shutterDevice

  describe "#parseAction()", ->
    moveUpCalled = false
    moveDownCalled = false
    stopCalled = false

    beforeEach ->
      moveUpCalled = false
      shutterDevice.moveUp = ->
        moveUpCalled = true
        return Promise.resolve true

      moveDownCalled = false
      shutterDevice.moveDown = ->
        moveDownCalled = true
        return Promise.resolve true
      stopCalled = false
      shutterDevice.stop = ->
        stopCalled = true
        return Promise.resolve true

    it "should parse: raise shutter up", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('raise shutter up', context)
      assert result?
      assert result.token is 'raise shutter up'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveUpCalled
        assert message is "raised shutter"
        finish()
      ).done()

    it "should parse: raise shutter", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('raise shutter', context)
      assert result?
      assert result.token is 'raise shutter'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveUpCalled
        assert message is "raised shutter"
        finish()
      ).done()


    it "should parse: move shutter up", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('move shutter up', context)
      assert result?
      assert result.token is 'move shutter up'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveUpCalled
        assert message is "raised shutter"
        finish()
      ).done()

    it "should parse: lower shutter down", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('lower shutter down', context)
      assert result?
      assert result.token is 'lower shutter down'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveDownCalled
        assert message is "lowered shutter"
        finish()
      ).done()

    it "should parse: lower shutter", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('lower shutter', context)
      assert result?
      assert result.token is 'lower shutter'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveDownCalled
        assert message is "lowered shutter"
        finish()
      ).done()

    it "should parse: move shutter down", (finish) ->
      context = createDummyParseContext()
      result = shutterActionProvider.parseAction('move shutter down', context)
      assert result?
      assert result.token is 'move shutter down'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert moveDownCalled
        assert message is "lowered shutter"
        finish()
      ).done()

    it "should parse: stop shutter", (finish) ->
      context = createDummyParseContext()
      result = stopShutterActionProvider.parseAction('stop shutter', context)
      assert result?
      assert result.token is 'stop shutter'
      assert result.nextInput is ""
      assert result.actionHandler?
      result.actionHandler.executeAction(false).then( (message) ->
        assert stopCalled
        assert message is "stopped shutter"
        finish()
      ).done()

describe "DimmerActionHandler", ->

  envDummy =
    logger: {}

  frameworkDummy = new events.EventEmitter()
  frameworkDummy.deviceManager = {
    devices: {}
    getDevices: -> _.values(@devices)
  }
  frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [])

  dimmerActionProvider = new env.actions.DimmerActionProvider frameworkDummy

  class DimmerDevice extends env.devices.DimmerActuator
    id: 'dummy-dimmer-id'
    name: 'dummy dimmer'

  dummyDimmer = new DimmerDevice()
  frameworkDummy.deviceManager.devices['dummy-dimmer-id'] = dummyDimmer

  describe "#executeAction()", ->
    dimlevel = null

    beforeEach ->
      dimlevel = null
      dummyDimmer.changeDimlevelTo = (dl) ->
        dimlevel = dl
        return Promise.resolve()

    validRulePrefixes = [
      'dim the dummy dimmer to'
      'dim dummy dimmer to'
    ]

    for rulePrefix in validRulePrefixes
      do (rulePrefix) ->
        action = "#{rulePrefix} 10%"
        it "should execute: #{action}", (finish) ->
          context = createDummyParseContext()
          result = dimmerActionProvider.parseAction(action, context)
          assert result.actionHandler?
          result.actionHandler.executeAction(false).then( (message) ->
            assert dimlevel is 10
            assert message is "dimmed dummy dimmer to 10%"
            finish()
          ).done()

describe "LogActionProvider", ->

  envDummy =
    logger: {}
  frameworkDummy = new events.EventEmitter()
  frameworkDummy.deviceManager = {
    devices: {}
    getDevices: -> _.values(@devices)
  }
  frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [])

  logActionProvider = new env.actions.LogActionProvider frameworkDummy
  actionHandler = null

  describe "#parseAction()", =>
    it 'should parse: log "a test message"', ->
      context = createDummyParseContext()
      result = logActionProvider.parseAction('log "a test message"', context)
      assert result?
      assert result.token is 'log "a test message"'
      assert result.nextInput is ''
      assert result.actionHandler?
      actionHandler = result.actionHandler

  describe "LogActionHandler", ->
    describe "#executeAction()", =>
      it 'should execute the action', (finish) ->
        actionHandler.executeAction(false).then( (message) ->
          assert message is "a test message"
          finish()
        ).done()


describe "SetVariableActionProvider", ->

  envDummy =
    logger: {}
  frameworkDummy = new events.EventEmitter()
  frameworkDummy.deviceManager = {
    devices: {}
    getDevices: -> _.values(@devices)
  }
  frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [{
    name: "a"
    type: "value"
    value: "2"
  }])
  frameworkDummy.variableManager.variables = {}
  frameworkDummy.variableManager.init()
  setVarActionProvider = new env.actions.SetVariableActionProvider frameworkDummy
  actionHandler1 = null
  actionHandler2 = null

  describe "#parseAction()", =>
    it 'should parse: set $a to 1', ->

      context = createDummyParseContext()
      result = setVarActionProvider.parseAction('set $a to 1', context)
      assert result?
      assert result.token is 'set $a to 1'
      assert result.nextInput is ''
      assert result.actionHandler?
      actionHandler1 = result.actionHandler

    it 'should parse: set $a to "abc"', ->
      context = createDummyParseContext()
      result = setVarActionProvider.parseAction('set $a to "abc"', context)
      assert result?
      assert result.token is 'set $a to "abc"'
      assert result.nextInput is ''
      assert result.actionHandler?
      actionHandler2 = result.actionHandler

  describe "LogActionHandler", ->

    describe "#executeAction()", =>
      it 'should execute the action 1', (finish) ->
        actionHandler1.executeAction(false).then( (message) ->
          assert message is "set $a to 1"
          finish()
        ).done()

      it 'should execute the action 2', (finish) ->
        actionHandler2.executeAction(false).then( (message) ->
          assert message is "set $a to abc"
          finish()
        ).done()