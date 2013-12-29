assert = require "cassert"
Q = require 'q'
actions = require '../lib/actions'
actuators = require '../lib/actuators'
i18n = require 'i18n'

i18n.configure(
  locales:['en', 'de']
  directory: __dirname + '/../locales'
  defaultLocale: 'en'
)

describe "SwitchActionHandler", ->

  envDummy =
    logger: {}

  frameworkDummy =
    actuators: {}

  switchActionHandler = new actions.SwitchActionHandler envDummy, frameworkDummy

  class DummySwitch extends actuators.SwitchActuator
    id: 'dummy-switch-id'
    name: 'dummy switch'

  dummySwitch = new DummySwitch()
  frameworkDummy.actuators['dummy-switch-id'] = dummySwitch

  describe "#executeAction()", ->
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
      'dummy switch'
      'dummy-switch-id'
    ]

    for rulePrefix in validRulePrefixes
      do (rulePrefix) ->

        ruleWithOn = rulePrefix + ' on'
        it "should execute: #{ruleWithOn}", (finish) ->
          switchActionHandler.executeAction(ruleWithOn, false).then( (message) ->
            assert turnOnCalled
            assert message is "turned dummy switch on"
            finish()
          ).done()

        ruleWithOff = rulePrefix + ' off'
        it "should execute: #{ruleWithOff}", (finish) ->
          switchActionHandler.executeAction(ruleWithOff, false).then( (message) ->
            assert turnOffCalled
            assert message is "turned dummy switch off"
            finish()
          ).done()

    it 'should not execute: invalid-id on', ->
      result = switchActionHandler.executeAction("invalid-id on", false)
      assert not result?
      assert not turnOnCalled

    it 'should not execute: another dummy switch on', ->
      result = switchActionHandler.executeAction("another dummy switch on", false)
      assert not result?
      assert not turnOnCalled

describe "LogActionHandler", ->

  envDummy =
    logger: {}
  frameworkDummy = {}

  logActionHandler = new actions.LogActionHandler envDummy, frameworkDummy

  describe "#executeAction()", =>

    it 'should execute: log "a test message"', (finish)->

      logCalled = false
      envDummy.logger.info = (message) =>
        logCalled = true
        assert message is 'a test message'

      logActionHandler.executeAction('log "a test message"', false).then( (message) ->
        assert message is null
        assert logCalled
        finish()
      ).done()
