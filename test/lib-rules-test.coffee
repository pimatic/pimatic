cassert = require "cassert"
assert = require "assert"
Q = require 'q'
S = require 'string'

env = require('../startup').env

describe "RuleManager", ->

  before ->
    env.logger.transports.console.level = 'error'

  ruleManager = null

  getTime = -> new Date().getTime()

  class DummyPredicateHandler extends env.predicates.PredicateHandler

    constructor: -> 
    getValue: -> Q(false)
    destroy: -> 
    getType: -> 'state'

  class DummyPredicateProvider extends env.predicates.PredicateProvider
    type: 'unknwon'
    name: 'test'

    parsePredicate: (input, context) -> 
      cassert S(input).startsWith("predicate 1")
      return {
        token: "predicate 1"
        nextInput: S(input).chompLeft("predicate 1").s
        predicateHandler: new DummyPredicateHandler()
      }

  class DummyActionHandler extends env.actions.ActionHandler

    executeAction: (simulate) =>
      return Q "action 1 executed"

  class DummyActionProvider

    parseAction: (input, context) -> 
      cassert S(input).startsWith("action 1")
      return {
        token: "action 1"
        nextInput: S(input).chompLeft("action 1").s
        actionHandler: new DummyActionHandler()
      }

  predProvider = new DummyPredicateProvider()
  serverDummy = {}
  ruleManager = new env.rules.RuleManager(serverDummy, [])
  ruleManager.addPredicateProvider predProvider
  actionProvider = new DummyActionProvider()
  ruleManager.actionProviders = [actionProvider]

  describe '#parseRuleCondition', ->
    context = null

    beforeEach ->
      context = ruleManager.createParseContext()

    testCases = [
      {
        input: "predicate 1"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: null,
              for: null 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')' ] 
        }
      }
      {
        input: "predicate 1 for 10 seconds"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: '10 seconds',
              for: 10000 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')' ] 
        }
      }
      {
        input: "predicate 1 for 2 hours"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: '2 hours',
              for: 7200000 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')' ] 
        }
      }
      {
        input: "predicate 1 and predicate 1"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: null
              for: null 
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              forToken: null
              for: null 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')' ] 
        }
      }
      {
        input: "predicate 1 or predicate 1"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: null
              for: null 
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              forToken: null
              for: null 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'or', 'predicate', '(', 1, ')' ] 
        }
      }
      {
        input: "predicate 1 for 2 hours or predicate 1"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              forToken: '2 hours',
              for: 7200000 
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              forToken: null
              for: null 
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'or', 'predicate', '(', 1, ')' ] 
        }
      }
    ]

    for tc in testCases
      do (tc) ->
        it "it should parse \"#{tc.input}\"", ->
          result = ruleManager.parseRuleCondition("test1", tc.input, context)
          assert.deepEqual result, tc.result

  describe '#parseRuleActions', ->
    context = null

    beforeEach ->
      context = ruleManager.createParseContext()

    testCases = [
      {
        input: "action 1"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
            } 
          ],
          tokens: [ 'action', '(', 0, ')' ] 
        }
      }
      {
        input: "action 1 and action 1"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
            }
            { 
              id: 'act-test1-1', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
            } 
          ],
          tokens: [ 'action', '(', 0, ')', 'and', 'action', '(', 1, ')' ] 
        }
      }
    ]

    for tc in testCases
      do (tc) ->
        it "it should parse \"#{tc.input}\"", ->
          result = ruleManager.parseRuleActions("test1", tc.input, context)
          assert result?
          for action in result.actions
            assert action.handler instanceof env.actions.ActionHandler
            action.handler = {}
          assert.deepEqual result, tc.result

  describe '#parseRuleString()', ->
    context = null

    beforeEach ->
      context = ruleManager.createParseContext()


    it 'should parse: "if predicate 1 then action 1"', (finish) ->
      ruleManager.parseRuleString("test1", "if predicate 1 then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'if predicate 1 then action 1'
        finish() 
      ).catch(finish).done()

    ruleWithForSuffix = 'if predicate 1 for 10 seconds then action 1'
    it """should parse rule with for "10 seconds" suffix: #{ruleWithForSuffix}'""", (finish) ->

      ruleManager.parseRuleString("test1", ruleWithForSuffix, context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 10 seconds'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is '10 seconds'
        cassert rule.predicates[0].for is 10*1000
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'if predicate 1 for 10 seconds then action 1'
        finish() 
      ).catch(finish).done()


    ruleWithHoursSuffix = "if predicate 1 for 2 hours then action 1"
    it """should parse rule with for "2 hours" suffix: #{ruleWithHoursSuffix}""", (finish) ->

      ruleManager.parseRuleString("test1", ruleWithHoursSuffix, context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 2 hours'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is '2 hours'
        cassert rule.predicates[0].for is 2*60*60*1000
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'if predicate 1 for 2 hours then action 1'
        finish() 
      ).catch(finish).done()

    it 'should not detect for "42 foo" as for suffix', (finish) ->

      ruleManager.parseRuleString("test1", "if predicate 1 for 42 foo then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 42 foo'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].forToken is null
        cassert rule.predicates[0].for is null
        cassert rule.actionsToken is 'action 1'
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
      predProvider.parsePredicate = (input, context) -> 
        cassert input is "predicate 2"
        canDecideCalled = true
        return null

      ruleManager.parseRuleString('test3', 'if predicate 2 then action 1', context).then( -> 
        cassert context.hasErrors()
        cassert context.errors.length is 1
        errorMsg = context.errors[0]
        cassert(
          errorMsg is 'Could not find an provider that decides next predicate of "predicate 2".'
        )
        cassert canDecideCalled
        finish()
      ).catch(finish)

    it 'should reject unknown action', (finish) ->
      canDecideCalled = false
      predProvider.parsePredicate = (input, context) -> 
        cassert input is "predicate 1"
        canDecideCalled = true
        return {
          token: "predicate 1"
          nextInput: S(input).chompLeft("predicate 1").s
          predicateHandler: new DummyPredicateHandler()
        }

      parseActionCalled = false
      actionProvider.parseAction = (input) =>
        cassert input is "action 2"
        parseActionCalled = true
        return null

      ruleManager.parseRuleString('test4', 'if predicate 1 then action 2', context).then( -> 
        cassert context.hasErrors()
        cassert context.errors.length is 1
        errorMsg = context.errors[0]
        cassert(
          errorMsg is 'Could not find an provider that provides the next action of "action 2".'
        )
        cassert parseActionCalled
        finish()
      ).catch(finish)

  notifyId = null

  # ###Tests for `addRuleByString()`
  describe '#addRuleByString()', ->

    changeHandler = null

    before ->
      predProvider.parsePredicate = (input, context) -> 
        cassert S(input).startsWith("predicate 1")
        predHandler = new DummyPredicateHandler()
        predHandler.on = (event, handler) -> 
          cassert event is 'change'
          changeHandler = handler
        return {
          token: "predicate 1"
          nextInput: S(input).chompLeft("predicate 1").s
          predicateHandler: predHandler
        }

    it 'should add the rule', (finish) ->

      parseActionCallCount = 0
      actionProvider.parseAction = (input) =>
        cassert input is "action 1"
        parseActionCallCount++
        return {
          token: "action 1"
          nextInput: S(input).chompLeft("action 1").s
          actionHandler: new DummyActionHandler()
        }

      ruleManager.addRuleByString('test5', 'if predicate 1 then action 1').then( ->
        cassert changeHandler?
        cassert parseActionCallCount is 1
        cassert ruleManager.rules['test5']?
        finish()
      ).catch(finish).done()

    it 'should react to notifies', (finish) ->
      this.timeout 3000

      ruleManager.rules['test5'].actions[0].handler.executeAction = (simulate) =>
        cassert not simulate
        finish()
        return Q "execute action"

      setTimeout((-> changeHandler('event')), 2001)


  # ###Tests for `updateRuleByString()`
  describe '#doesRuleCondtionHold', ->

    predHandler1 = null
    predHandler2 = null

    beforeEach ->
      predHandler1 = new DummyPredicateHandler()
      predHandler1.on = (event, listener) -> 
        cassert event is 'change'
      predHandler1.getValue = => Q true
      predHandler1.getType = => "state"

      predHandler2 = new DummyPredicateHandler()
      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
      predHandler2.getValue = => Q true
      predHandler2.getType = => "state"


    it 'should decide predicate 1', (finish)->

      rule =
        id: "test1"
        orgCondition: "predicate 1"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          handler: predHandler1
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
        predHandler1.getValue = => Q false 
      ).then( -> ruleManager.doesRuleCondtionHold rule).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 and predicate 2', (finish)->

      rule =
        id: "test1"
        orgCondition: "predicate 1 and predicate 2"
        predicates: [
          {
            id: "test1,"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            for: null
          }
          {
            id: "test2,"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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
        predHandler1.getValue = => Q true
        predHandler2.getValue = => Q false
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide predicate 1 or predicate 2', (finish)->

      rule =
        id: "test1"
        orgCondition: "predicate 1 or predicate 2"
        predicates: [
          {
            id: "test1,"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            for: null
          }
          {
            id: "test2,"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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
        predHandler1.getValue = => Q true
        predHandler2.getValue = => Q false
      ).then( -> ruleManager.doesRuleCondtionHold rule ).then( (isTrue) ->
        cassert isTrue is true
        finish()
      ).catch(finish).done()


    it 'should decide predicate 1 for 1 second (holds)', (finish)->
      this.timeout 2000
      start = getTime()

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          handler: predHandler1
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

      predHandler1.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          listener false
        , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second"
        predicates: [
          id: "test1,"
          token: "predicate 1"
          type: "state"
          handler: predHandler1
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
        cassert isTrue is false
        cassert elapsed < 1000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second and predicate 2 for 2 seconds (holds)', (finish)->
      this.timeout 3000
      start = getTime()

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second and predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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

      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          listener false
        , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second and predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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

      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          listener false
        , 500

      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second or predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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
        cassert elapsed >= 1000
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second or predicate 2 for 2 seconds (does not holds)', 
    (finish)->
      this.timeout 3000
      start = getTime()

      predHandler1.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          listener false
        , 500

      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          listener false
        , 500


      rule =
        id: "test1"
        orgCondition: "predicate 1 for 1 second or predicate 2 for 2 seconds"
        predicates: [
          {
            id: "test1"
            token: "predicate 1"
            type: "state"
            handler: predHandler1
            forToken: "1 second"
            for: 1000
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
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


  predHandler = null
  actHandler = null
  # ###Tests for `updateRuleByString()`
  describe '#updateRuleByString()', ->  

    changeListener = null
    i = 1

    it 'should update the rule', (finish) ->

      parsePredicateCalled = false
      onCalled = false
      predProvider.parsePredicate = (input, context) -> 
        cassert S(input).startsWith("predicate 2")
        parsePredicateCalled = i
        i++
        predHandler = new DummyPredicateHandler()
        predHandler.on = (event, listener) -> 
          cassert event is 'change'
          changeListener = listener
          onCalled = i
          i++

        predHandler.getVale = => Q true
        predHandler.getType => 'event'
        return {
          token: "predicate 2"
          nextInput: S(input).chompLeft("predicate 2").s
          predicateHandler: predHandler
        }

      actionProvider.parseAction = (input, context) -> 
        cassert S(input).startsWith("action 1")
        actHandler = new DummyActionHandler()
        actHandler.executeAction = (simulate) => Q "execute action"
        return {
          token: "action 1"
          nextInput: S(input).chompLeft("action 1").s
          actionHandler: actHandler
        }

      ruleManager.updateRuleByString('test5', 'if predicate 2 then action 1').then( ->
        cassert parsePredicateCalled is 1
        cassert onCalled is 2

        cassert ruleManager.rules['test5']?
        cassert ruleManager.rules['test5'].string is 'if predicate 2 then action 1'
        finish()
      ).catch(finish).done()


    it 'should react to notifies', (finish) ->
      this.timeout 3000

      actHandler.executeAction = (simulate) =>
        cassert not simulate
        finish()
        return Q "execute action"

      setTimeout( ->
        changeListener('event')
      , 2001
      )


  # ###Tests for `removeRule()`
  describe '#removeRule()', ->

    it 'should remove the rule', ->
      removeListenerCalled = false
      predHandler.removeListener = (event, listener) ->
        cassert event is "change"
        removeListenerCalled = true
        return true

      ruleManager.removeRule 'test5'
      cassert not ruleManager.rules['test5']?
      cassert removeListenerCalled
