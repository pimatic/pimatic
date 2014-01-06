assert = require "cassert"
Q = require 'q'

describe "RuleManager", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'

  before ->
    env.logger.transports.console.level = 'error'

  ruleManager = null

  class DummyPredicateProvider extends env.predicates.PredicateProvider
    type: 'unknwon'
    name: 'test'

    canDecide: (predicate) -> 
      assert predicate is "predicate 1"
      return 'event'
    isTrue: (id, predicate) -> Q.fcall -> false
    notifyWhen: (id, predicate, callback) -> true
    cancelNotify: (id) -> true

  class DummyActionHandler
    executeAction: (actionString, simulate) =>
      assert actionString is "action 1"
      return Q.fcall -> "action 1 executed"


  provider = new DummyPredicateProvider
  serverDummy = {}
  ruleManager = new env.rules.RuleManager serverDummy, []
  ruleManager.addPredicateProvider provider
  actionHandler = new DummyActionHandler
  ruleManager.actionHandlers = [actionHandler]

  # ###Tests for `parseRuleString()`
  describe '#parseRuleString()', ->

    it 'should parse valid rule', (finish) ->
      ruleManager.parseRuleString("test1", "if predicate 1 then action 1")
      .then( (rule) -> 
        assert rule.id is 'test1'
        assert rule.orgCondition is 'predicate 1'
        assert rule.tokens.length > 0
        assert rule.predicates.length is 1
        assert rule.action is 'action 1'
        assert rule.string is 'if predicate 1 then action 1'
        finish() 
      ).catch(finish).done()

    it 'should parse rule with for suffix', (finish) ->

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1" or predicate is 'predicate 1 for 10 seconds'
        return if predicate is "predicate 1" then 'state' else no

      ruleManager.parseRuleString("test1", "if predicate 1 for 10 seconds then action 1")
      .then( (rule) -> 
        assert rule.id is 'test1'
        assert rule.orgCondition is 'predicate 1 for 10 seconds'
        assert rule.tokens.length > 0
        assert rule.predicates.length is 1
        assert rule.predicates[0].forToken is '10 seconds'
        assert rule.predicates[0].for is 10000
        assert rule.action is 'action 1'
        assert rule.string is 'if predicate 1 for 10 seconds then action 1'
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

      provider.canDecide = (predicate) ->
        assert predicate is 'predicate 2'
        return false

      ruleManager.parseRuleString('test3', 'if predicate 2 then action 1').then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        assert error?
        assert error.message is 'Could not find an provider that decides "predicate 2"'
        finish()
      ).done()

    it 'should reject unknown action', (finish) ->
      canDecideCalled = false
      provider.canDecide = (predicate) ->
        assert predicate is "predicate 1"
        canDecideCalled = true
        return 'event'

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

  # ###Tests for `addRuleByString()`
  describe '#addRuleByString()', ->

    notifyCallback = null

    it 'should add the rule', (finish) ->
      provider.notifyWhen = (id, predicate, callback) -> 
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

    it 'should react to notifies', (finish) ->

      actionHandler.executeAction = (actionString, simulate) =>
        assert actionString is "action 1"
        assert not simulate
        finish()
        return Q.fcall -> "execute action"

      notifyCallback('event')

  # ###Tests for `updateRuleByString()`
  describe '#doesRuleCondtionHold', ->

    it 'should decide predicate 1', (finish)->

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> true

      rule =
        id: "test1"
        orgCondition: "predicate 1"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          provider: provider
          for: null
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "if predicate 1 then action 1"


      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        assert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> false 
      ).then( -> ruleManager.doesRuleCondtionHold rule).then( (isTrue) ->
        assert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 and predicate 2', (finish)->

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> true

      rule =
        id: "test1"
        orgCondition: "predicate 1 and predicate 2"
        predicates: [
          {
            id: "test1,"
            token: "predicate 1"
            type: "state"
            provider: provider
            for: null
          }
          {
            id: "test2,"
            token: "predicate 2"
            type: "state"
            provider: provider
            for: null
          }
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
          "and"
          "predicate"
          "("
          1
          ")"
        ]
        action: "action 1"
        string: "if predicate 1 and predicate 2 then action 1"


      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        assert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> (predicate is 'predicate 1') 
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        assert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 or predicate 2', (finish)->

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> true

      rule =
        id: "test1"
        orgCondition: "predicate 1 or predicate 2"
        predicates: [
          {
            id: "test1,"
            token: "predicate 1"
            type: "state"
            provider: provider
            for: null
          }
          {
            id: "test2,"
            token: "predicate 2"
            type: "state"
            provider: provider
            for: null
          }
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
          "or"
          "predicate"
          "("
          1
          ")"
        ]
        action: "action 1"
        string: "if predicate 1 or predicate 2 then action 1"


      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        assert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> (predicate is 'predicate 1') 
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        assert isTrue is true
        finish()
      ).catch(finish).done()


    it 'should decide predicate 1 for 1 second (holds)', (finish)->
      this.timeout 2000

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> 
        assert predicate is "predicate 1"
        return true

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          provider: provider
          forToken: "1 second"
          for: 1000
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "if predicate 1 for 1 second then action 1"


      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        assert isTrue is true
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second (does not hold)', (finish)->
      this.timeout 2000

      provider.canDecide = (predicate) -> 
        assert predicate is "predicate 1"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true

      notifyCallback = null
      provider.notifyWhen = (id, predicate, callback) -> 
        assert predicate is "predicate 1"
        notifyCallback = callback
        return true

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          provider: provider
          forToken: "1 second"
          for: 1000
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "if predicate 1 for 1 second then action 1"

      setTimeout ->
        notifyCallback false
      , 500


      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        assert isTrue is false
        finish()
      ).done()


  # ###Tests for `updateRuleByString()`
  describe '#updateRuleByString()', ->

    notfyCallback = null
    i = 1

    it 'should update the rule', (finish) ->

      canDecideCalled = false
      provider.canDecide = (predicate) ->
        assert predicate is 'predicate 2'
        canDecideCalled = i
        i++
        return 'event'

      cancleNotifyCalled = false
      provider.cancelNotify = (id) ->
        assert id?
        assert id is notifyId
        cancleNotifyCalled = i
        i++
        return true

      notifyWhenCalled = false
      provider.notifyWhen = (id, predicate, callback) -> 
        assert id?
        assert predicate is 'predicate 2'
        assert typeof callback is 'function'
        notfyCallback = callback
        notifyWhenCalled = i
        i++
        return true

      provider.isTrue = -> Q.fcall -> true

      actionHandler.executeAction = (actionString, simulate) => Q.fcall -> "execute action"

      ruleManager.updateRuleByString('test5', 'if predicate 2 then action 1').then( ->
        assert canDecideCalled is 1
        assert cancleNotifyCalled is 2
        assert notifyWhenCalled is 3

        assert ruleManager.rules['test5']?
        assert ruleManager.rules['test5'].string is 'if predicate 2 then action 1'
        finish()
      ).catch(finish).done()


    it 'should react to notifies', (finish) ->

      actionHandler.executeAction = (actionString, simulate) =>
        assert actionString is "action 1"
        assert not simulate
        finish()
        return Q.fcall -> "execute action"

      notfyCallback 'event'

  # ###Tests for `removeRule()`
  describe '#removeRule()', ->

    it 'should remove the rule', ->
      cancleNotifyCalled = false
      provider.cancelNotify = (id) ->
        assert id?
        cancleNotifyCalled = true
        return true

      ruleManager.removeRule 'test5'
      assert not ruleManager.rules['test5']?
      assert cancleNotifyCalled

