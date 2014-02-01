cassert = require "cassert"
assert = require "assert"
Q = require 'q'

describe "RuleManager", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'

  before ->
    env.logger.transports.console.level = 'error'

  ruleManager = null

  getTime = -> new Date().getTime()

  class DummyPredicateProvider extends env.predicates.PredicateProvider
    type: 'unknwon'
    name: 'test'

    canDecide: (predicate) -> 
      cassert predicate is "predicate 1"
      return 'event'
    isTrue: (id, predicate) -> Q.fcall -> false
    notifyWhen: (id, predicate, callback) -> true
    cancelNotify: (id) -> true

  class DummyActionHandler
    executeAction: (actionString, simulate) =>
      cassert actionString is "action 1"
      return Q.fcall -> "action 1 executed"


  provider = new DummyPredicateProvider
  serverDummy = {}
  ruleManager = new env.rules.RuleManager serverDummy, []
  ruleManager.addPredicateProvider provider
  actionHandler = new DummyActionHandler
  ruleManager.actionHandlers = [actionHandler]

  # ###Tests for `parseRuleString()`
  describe '#parseRuleString()', ->

    context = null

    beforeEach ->
      context = ruleManager.createParseContext()

    it 'should parse valid rule', (finish) ->
      ruleManager.parseRuleString("test1", "if predicate 1 then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.orgCondition is 'predicate 1'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.action is 'action 1'
        cassert rule.string is 'if predicate 1 then action 1'
        finish() 
      ).catch(finish).done()

    it 'should parse rule with for "10 seconds" suffix', (finish) ->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1"
        return 'state'

      ruleManager.parseRuleString("test1", "if predicate 1 for 10 seconds then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.orgCondition is 'predicate 1 for 10 seconds'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is '10 seconds'
        cassert rule.predicates[0].for is 10*1000
        cassert rule.action is 'action 1'
        cassert rule.string is 'if predicate 1 for 10 seconds then action 1'
        finish() 
      ).catch(finish).done()

    it 'should parse rule with for "2 hours" suffix', (finish) ->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1"
        return 'state'

      ruleManager.parseRuleString("test1", "if predicate 1 for 2 hours then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.orgCondition is 'predicate 1 for 2 hours'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is '2 hours'
        cassert rule.predicates[0].for is 2*60*60*1000
        cassert rule.action is 'action 1'
        cassert rule.string is 'if predicate 1 for 2 hours then action 1'
        finish() 
      ).catch(finish).done()

    it 'should not detect for "42 foo" as for suffix', (finish) ->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1 for 42 foo"
        return 'state'

      ruleManager.parseRuleString("test1", "if predicate 1 for 42 foo then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.orgCondition is 'predicate 1 for 42 foo'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is null
        cassert rule.predicates[0].for is null
        cassert rule.action is 'action 1'
        cassert rule.string is 'if predicate 1 for 42 foo then action 1'
        finish() 
      ).catch(finish).done()


    it 'should reject wrong rule format', (finish) ->
      # Missing `then`:
      ruleManager.parseRuleString("test2", "if predicate 1 and action 1", context)
      .then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        cassert error?
        cassert error.message is 'The rule must start with "if" and contain a "then" part!'
        finish()
      ).done()

    it 'should reject unknown predicate', (finish) ->
      canDecideCalled = false
      provider.canDecide = (predicate) ->
        cassert predicate is 'predicate 2'
        canDecideCalled = true
        return false

      ruleManager.parseRuleString('test3', 'if predicate 2 then action 1', context).then( -> 
        cassert context.hasErrors()
        cassert context.errors.length is 1
        errorMsg = context.errors[0]
        cassert errorMsg is 'Could not find an provider that decides "predicate 2".'
        cassert canDecideCalled
        finish()
      ).catch(finish)

    it 'should reject unknown action', (finish) ->
      canDecideCalled = false
      provider.canDecide = (predicate) ->
        cassert predicate is "predicate 1"
        canDecideCalled = true
        return 'event'

      executeActionCalled = false
      actionHandler.executeAction = (actionString, simulate) =>
        cassert actionString is "action 2"
        cassert simulate
        executeActionCalled = true
        return

      ruleManager.parseRuleString('test4', 'if predicate 1 then action 2', context).then( -> 
        cassert context.hasErrors()
        cassert context.errors.length is 1
        errorMsg = context.errors[0]
        cassert errorMsg is 'Could not find an action handler for: action 2'
        cassert executeActionCalled
        finish()
      ).catch(finish)

  notifyId = null

  # ###Tests for `addRuleByString()`
  describe '#addRuleByString()', ->

    notifyCallback = null

    it 'should add the rule', (finish) ->
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert id?
        cassert predicate is 'predicate 1'
        cassert typeof callback is 'function'
        notifyCallback = callback
        notifyId = id
        return true

      executeActionCallCount = 0
      actionHandler.executeAction = (actionString, simulate) =>
        cassert actionString is "action 1"
        cassert simulate
        executeActionCallCount++
        return Q.fcall -> "execute action"

      ruleManager.addRuleByString('test5', 'if predicate 1 then action 1').then( ->
        cassert notifyCallback?
        cassert executeActionCallCount is 1
        cassert ruleManager.rules['test5']?
        finish()
      ).catch(finish).done()

    it 'should react to notifies', (finish) ->

      actionHandler.executeAction = (actionString, simulate) =>
        cassert actionString is "action 1"
        cassert not simulate
        finish()
        return Q.fcall -> "execute action"

      notifyCallback('event')

  # ###Tests for `updateRuleByString()`
  describe '#doesRuleCondtionHold', ->

    it 'should decide predicate 1', (finish)->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1"
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
        cassert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> false 
      ).then( -> ruleManager.doesRuleCondtionHold rule).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 and predicate 2', (finish)->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
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
        cassert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> (predicate is 'predicate 1') 
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 or predicate 2', (finish)->

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
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
        cassert isTrue is true
      ).then( -> 
        provider.isTrue = (id, predicate) -> Q.fcall -> (predicate is 'predicate 1') 
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        cassert isTrue is true
        finish()
      ).catch(finish).done()


    it 'should decide predicate 1 for 1 second (holds)', (finish)->
      this.timeout 2000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1"
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
        elapsed = getTime() - start
        cassert isTrue is true
        cassert elapsed >= 1000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second (does not hold)', (finish) ->
      this.timeout 2000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true

      notifyCallback = null
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1"
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
        elapsed = getTime() - start
        cassert isTrue is false
        cassert elapsed < 1000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second and predicate 2 for 2 seconds (holds)', (finish)->
      this.timeout 3000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        return true

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second and predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            provider: provider
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            provider: provider
            forToken: "2 seconds"
            for: 2000
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
        string: "if predicate 1 for 1 second and predicate 2 for 2 seconds then action 1"

      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        elapsed = getTime() - start
        cassert isTrue is true
        cassert elapsed >= 2000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second and predicate 2 for 2 seconds (does not holds)', 
    (finish)->
      this.timeout 3000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        if predicate is "predicate 1"
          setTimeout ->
            callback false
          , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second and predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            provider: provider
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            provider: provider
            forToken: "2 seconds"
            for: 2000
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
        string: "if predicate 1 for 1 second and predicate 2 for 2 seconds then action 1"

      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        elapsed = getTime() - start
        cassert isTrue is false
        cassert elapsed < 3000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second or predicate 2 for 2 seconds (holds)', (finish)->
      this.timeout 3000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true

      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        if predicate is "predicate 1"
          setTimeout ->
            callback false
          , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second or predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            provider: provider
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            provider: provider
            forToken: "2 seconds"
            for: 2000
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
        string: "if predicate 1 for 1 second or predicate 2 for 2 seconds then action 1"

      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        elapsed = getTime() - start
        cassert isTrue is true
        cassert elapsed >= 2000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second or predicate 2 for 2 seconds (does not holds)', 
    (finish)->
      this.timeout 3000
      start = getTime()

      provider.canDecide = (predicate) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        return 'state'

      provider.isTrue = (id, predicate) -> Q.fcall -> true

      provider.notifyWhen = (id, predicate, callback) -> 
        cassert predicate is "predicate 1" or predicate is "predicate 2"
        setTimeout ->
          callback false
        , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second or predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            provider: provider
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            provider: provider
            forToken: "2 seconds"
            for: 2000
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
        string: "if predicate 1 for 1 second or predicate 2 for 2 seconds then action 1"

      ruleManager.doesRuleCondtionHold(rule).then( (isTrue) ->
        elapsed = getTime() - start
        cassert isTrue is false
        cassert elapsed < 1000
        finish()
      ).done()



  # ###Tests for `updateRuleByString()`
  describe '#updateRuleByString()', ->

    notfyCallback = null
    i = 1

    it 'should update the rule', (finish) ->

      canDecideCalled = false
      provider.canDecide = (predicate) ->
        cassert predicate is 'predicate 2'
        canDecideCalled = i
        i++
        return 'event'

      cancleNotifyCalled = false
      provider.cancelNotify = (id) ->
        cassert id?
        cassert id is notifyId
        cancleNotifyCalled = i
        i++
        return true

      notifyWhenCalled = false
      provider.notifyWhen = (id, predicate, callback) -> 
        cassert id?
        cassert predicate is 'predicate 2'
        cassert typeof callback is 'function'
        notfyCallback = callback
        notifyWhenCalled = i
        i++
        return true

      provider.isTrue = -> Q.fcall -> true

      actionHandler.executeAction = (actionString, simulate) => Q.fcall -> "execute action"

      ruleManager.updateRuleByString('test5', 'if predicate 2 then action 1').then( ->
        cassert canDecideCalled is 1
        cassert cancleNotifyCalled is 2
        cassert notifyWhenCalled is 3

        cassert ruleManager.rules['test5']?
        cassert ruleManager.rules['test5'].string is 'if predicate 2 then action 1'
        finish()
      ).catch(finish).done()


    it 'should react to notifies', (finish) ->

      actionHandler.executeAction = (actionString, simulate) =>
        cassert actionString is "action 1"
        cassert not simulate
        finish()
        return Q.fcall -> "execute action"

      notfyCallback 'event'

  # ###Tests for `removeRule()`
  describe '#removeRule()', ->

    it 'should remove the rule', ->
      cancleNotifyCalled = false
      provider.cancelNotify = (id) ->
        cassert id?
        cancleNotifyCalled = true
        return true

      ruleManager.removeRule 'test5'
      cassert not ruleManager.rules['test5']?
      cassert cancleNotifyCalled

  # ###Tests for `executeAction()`
  describe '#executeAction()', ->

    it 'should execute action 1', (finish) ->

      executeActionCallCount = 0
      actionHandler.executeAction = (actionString, simulate) =>
        cassert actionString is "action 1"
        cassert simulate
        executeActionCallCount++
        return Q.fcall -> "execute action"

      ruleManager.executeAction('action 1', true).then( ->
        cassert executeActionCallCount is 1
        finish()
      ).catch(finish).done()

    it 'should execute action 1 and action 2', (finish) ->

      executedWith = []
      actionHandler.executeAction = (actionString, simulate) =>
        executedWith.push actionString
        cassert simulate
        return Q.fcall -> "execute action"

      ruleManager.executeAction('action 1 and action 2', true).then( ->
        assert.deepEqual executedWith, ["action 1", "action 2"]
        finish()
      ).catch(finish).done()
