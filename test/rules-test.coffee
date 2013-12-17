assert = require "cassert"
Q = require 'q'

describe "RuleManager", ->

    # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    actuators: require '../lib/actuators'
    sensors: require '../lib/sensors'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'

  ruleManager = null

  class DummySensor extends env.sensors.Sensor
    type: 'unknwon'
    name: 'test'
    getSensorValuesNames: -> []
    getSensorValue: (name) -> throw new Error("no name available")
    canDecide: (predicate) -> 
      assert predicate is "predicate 1"
      return true
    isTrue: (id, predicate) -> Q.fcall -> false
    notifyWhen: (id, predicate, callback) -> true
    cancelNotify: (id) -> true

  class DummyActionHandler
    executeAction: (actionString, simulate) =>
      assert actionString is "action 1"
      return Q.fcall -> "action 1 executed"


  sensor = new DummySensor
  serverDummy = 
    sensors: [sensor]
  ruleManager = new env.rules.RuleManager serverDummy, []
  actionHandler = new DummyActionHandler
  ruleManager.actionHandlers = [actionHandler]

  describe '#parseRuleString()', ->

    it 'should parse valid rule', (finish) ->
      ruleManager.parseRuleString("test1", "if predicate 1 then action 1")
      .then( (rule) -> 
        assert rule.id is 'test1'
        assert rule.orgCondition is 'predicate 1'
        assert rule.tokens.length > 0
        assert rule.action is 'action 1'
        assert rule.string is 'if predicate 1 then action 1'
        finish() 
      ).catch(finish).done()

    it 'should reject wrong rule format', (finish) ->
      # Missing `then`:
      ruleManager.parseRuleString("test2", "if predicate 1 and action 1")
      .then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        assert error?
        assert error.message is 'The rule must start with "if" and contain a "then" part!'
        finish()
      ).done()

    it 'should reject unknown predicate', (finish) ->

      sensor.canDecide = (predicate) ->
        assert predicate is 'predicate 2'
        return false

      ruleManager.parseRuleString('test3', 'if predicate 2 then action 1').then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        assert error?
        assert error.message is 'Could not find an sensor that decides "predicate 2"'
        finish()
      ).done()

    it 'should reject unknown action', (finish) ->
      canDecideCalled = false
      sensor.canDecide = (predicate) ->
        assert predicate is "predicate 1"
        canDecideCalled = true
        return true

      executeActionCalled = false
      actionHandler.executeAction = (actionString, simulate) =>
        assert actionString is "action 2"
        assert simulate
        executeActionCalled = true
        return

      ruleManager.parseRuleString('test4', 'if predicate 1 then action 2').then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        assert error?
        assert error.message is 'Could not find a actuator to execute "action 2"'
        assert canDecideCalled
        assert executeActionCalled
        finish()
      ).done()

  notifyId = null

  describe '#addRuleByString()', ->

    notifyCallback = null

    it 'should add the rule', (finish) ->
      sensor.notifyWhen = (id, predicate, callback) -> 
        assert id?
        assert predicate is 'predicate 1'
        assert typeof callback is 'function'
        notifyCallback = callback
        notifyId = id
        return true

      executeActionCallCount = 0
      actionHandler.executeAction = (actionString, simulate) =>
        assert actionString is "action 1"
        assert simulate
        executeActionCallCount++
        return Q.fcall -> "execute action"

      ruleManager.addRuleByString('test5', 'if predicate 1 then action 1').then( ->
        assert notifyCallback?
        assert executeActionCallCount is 1
        assert ruleManager.rules['test5']?
        finish()
      ).catch(finish).done()

    it 'should execute the action', (finish) ->

      actionHandler.executeAction = (actionString, simulate) =>
        assert actionString is "action 1"
        assert not simulate
        finish()
        return Q.fcall -> "execute action"

      notifyCallback()

  describe '#updateRuleByString', ->

    it 'should update the rule', (finish) ->
      canDecideCalled = false
      sensor.canDecide = (predicate) ->
        assert predicate is 'predicate 2'
        canDecideCalled = true
        return true

      notifyWhenCalled = false
      sensor.notifyWhen = (id, predicate, callback) -> 
        assert id?
        assert predicate is 'predicate 2'
        assert typeof callback is 'function'
        notifyWhenCalled = true
        return true

      cancleNotifyCalled = false
      sensor.cancelNotify = (id) ->
        assert id?
        assert id is notifyId
        cancleNotifyCalled = true
        return true

      actionHandler.executeAction = (actionString, simulate) => Q.fcall -> "execute action"

      ruleManager.updateRuleByString('test5', 'if predicate 2 then action 1').then( ->
        assert canDecideCalled
        assert notifyWhenCalled
        assert cancleNotifyCalled
        assert ruleManager.rules['test5']?
        assert ruleManager.rules['test5'].string is 'if predicate 2 then action 1'
        finish()
      ).catch(finish).done()