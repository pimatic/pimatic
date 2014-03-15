assert = require "cassert"
Q = require 'q'
i18n = require 'i18n'

i18n.configure(
  locales:['en', 'de']
  directory: __dirname + '/../locales'
  defaultLocale: 'en'
)

env = require('../startup').env

describe "SwitchActionHandler", ->

  frameworkDummy =
    devices: {}

  switchActionProvider = new env.actions.SwitchActionProvider frameworkDummy

  class DummySwitch extends env.devices.SwitchActuator
    id: 'dummy-switch-id'
    name: 'dummy switch'

  dummySwitch = new DummySwitch()
  frameworkDummy.devices['dummy-switch-id'] = dummySwitch

  describe "#parseAction()", ->
    turnOnCalled = false
    turnOffCalled = false

    beforeEach ->
      turnOnCalled = false
      dummySwitch.turnOn = ->
        turnOnCalled = true
        return Q.fcall -> true

      turnOffCalled = false
      dummySwitch.turnOff = ->
        turnOffCalled = true
        return Q.fcall -> true

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
          result = switchActionProvider.parseAction(ruleWithOn)
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
          result = switchActionProvider.parseAction(ruleWithOff)
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
      result = switchActionProvider.parseAction("turn on the dummy switch")
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
      result = switchActionProvider.parseAction("invalid-id on")
      assert not result?
      assert not turnOnCalled

    it 'should not execute: another dummy switch on', ->
      result = switchActionProvider.parseAction("another dummy switch on", false)
      assert not result?
      assert not turnOnCalled

describe "DimmerActionHandler", ->

  envDummy =
    logger: {}

  frameworkDummy =
    devices: {}

  dimmerActionProvider = new env.actions.DimmerActionProvider frameworkDummy

  class DimmerDevice extends env.devices.DimmerActuator
    id: 'dummy-dimmer-id'
    name: 'dummy dimmer'

  dummyDimmer = new DimmerDevice()
  frameworkDummy.devices['dummy-dimmer-id'] = dummyDimmer

  describe "#executeAction()", ->
    dimlevel = null

    beforeEach ->
      dimlevel = null
      dummyDimmer.changeDimlevelTo = (dl) ->
        dimlevel = dl
        return Q()

    validRulePrefixes = [
      'dim the dummy dimmer to'
      'dim dummy dimmer to'
    ]

    for rulePrefix in validRulePrefixes
      do (rulePrefix) ->
        action = "#{rulePrefix} 10%"
        it "should execute: #{action}", (finish) ->
          result = dimmerActionProvider.parseAction(action)
          assert result.actionHandler?
          result.actionHandler.executeAction(false).then( (message) ->
            assert dimlevel is 10
            assert message is "dimmed dummy dimmer to 10%"
            finish()
          ).done()

describe "LogActionProvider", ->

  envDummy =
    logger: {}
  frameworkDummy = {}

  logActionProvider = new env.actions.LogActionProvider frameworkDummy
  actionHandler = null

  describe "#parseAction()", =>
    it 'should parse: log "a test message"', ->
      result = logActionProvider.parseAction('log "a test message"')
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
