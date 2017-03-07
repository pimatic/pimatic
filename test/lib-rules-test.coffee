cassert = require "cassert"
assert = require "assert"
Promise = require 'bluebird'
S = require 'string'
util = require 'util'
events = require 'events'

env = require('../startup').env

describe "RuleManager", ->

  rulesAst = require '../lib/rules-ast-builder'

  before ->
    env.logger.winston.transports.taggedConsoleLogger.level = 'error'

  ruleManager = null

  getTime = -> new Date().getTime()

  class DummyPredicateHandler extends env.predicates.PredicateHandler

    constructor: -> 
    getValue: -> Promise.resolve(false)
    destroy: -> 
    getType: -> 'state'

  class DummyPredicateProvider extends env.predicates.PredicateProvider
    type: 'unknown'
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
      return Promise.resolve "action 1 executed"

    hasRestoreAction: => yes

    executeRestoreAction: (simulate) =>
      return Promise.resolve "restore action 1 executed"

  class DummyActionProvider

    parseAction: (input, context) -> 
      cassert S(input).startsWith("action 1")
      return {
        token: "action 1"
        nextInput: S(input).chompLeft("action 1").s
        actionHandler: new DummyActionHandler()
      }

  predProvider = new DummyPredicateProvider()
  frameworkDummy = new events.EventEmitter()
  frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [])
  frameworkDummy.variableManager.init()
  ruleManager = new env.rules.RuleManager(frameworkDummy, [])
  ruleManager.addPredicateProvider predProvider
  actionProvider = new DummyActionProvider()
  ruleManager.actionProviders = [actionProvider]

  describe '#parseRuleCondition', ->
    context = null

    beforeEach ->
      context = ruleManager._createParseContext()

    testCases = [
      {
        input: "predicate 1"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              for: null
              justTrigger: false,
              justCondition: false
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
              for:
                token: '10 seconds'
                exprTokens: ['10']
                unit: 'seconds'
              justTrigger: false,
              justCondition: false
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
              for:
                token: '2 hours'
                exprTokens: ['2']
                unit: 'hours'
              justTrigger: false,
              justCondition: false
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
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')' ] 
        }
      }
      {
        input: "[predicate 1 and predicate 1]"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
          ]
          tokens: [ '[', 'predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')', ']' ] 
        }
      }
      {
        input: "predicate 1 and [predicate 1]"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'and', '[', 'predicate', '(', 1, ')', ']' ] 
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
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
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
              for: 
                token: '2 hours'
                exprTokens: [ '2']
                unit: 'hours'
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'or', 'predicate', '(', 1, ')' ] 
        }
      }
      {
        input: "predicate 1 and [predicate 1 or predicate 1]"
        result: { 
          predicates: [ 
            { 
              id: 'prd-test1-0',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-1',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
            { 
              id: 'prd-test1-2',
              token: 'predicate 1',
              handler: {},
              for: null 
              justTrigger: false,
              justCondition: false
            }
          ]
          tokens: [ 'predicate', '(', 0, ')', 'and', '[', 'predicate', '(', 1, ')', 
            'or', 'predicate', '(', 2, ')', ']' ] 
        }
      }
    ]

    for tc in testCases
      do (tc) ->
        it "it should parse \"#{tc.input}\"", ->
          result = ruleManager._parseRuleCondition("test1", tc.input, context, null, false)
          assert.deepEqual result, tc.result

  describe '#parseRuleActions', ->
    context = null

    beforeEach ->
      context = ruleManager._createParseContext()

    testCases = [
      {
        input: "action 1"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after: null
              for: null
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
              after: null
              for: null
            }
            { 
              id: 'act-test1-1', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after: null
              for: null
            } 
          ],
          tokens: [ 'action', '(', 0, ')', 'and', 'action', '(', 1, ')' ] 
        }
      }
      {
        input: "after 1 minute action 1"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '1 minute'
                exprTokens: [ 1 ]
                unit: 'minute'
              for: null
            } 
          ],
          tokens: [ 'action', '(', 0, ')' ] 
        }
      }
      {
        input: "action 1 after 1 minute"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '1 minute'
                exprTokens: [ 1 ]
                unit: 'minute'
              for: null
            } 
          ],
          tokens: [ 'action', '(', 0, ')' ] 
        }
      }
      {
        input: "after 2 minutes action 1 and after 1 hour action 1"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '2 minutes',
                exprTokens: [ 2],
                unit: 'minutes'
              for: null
            }
            { 
              id: 'act-test1-1', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '1 hour',
                exprTokens: [ 1 ],
                unit: 'hour'
              for: null
            } 
          ],
          tokens: [ 'action', '(', 0, ')', 'and', 'action', '(', 1, ')' ] 
        }
      }
      {
        input: "action 1 after 2 minutes and action 1 after 1 hour"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '2 minutes',
                exprTokens: [ 2 ],
                unit: 'minutes'
              for: null
            }
            { 
              id: 'act-test1-1', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after:
                token: '1 hour',
                exprTokens: [ 1 ],
                unit: 'hour'
              for: null
            } 
          ],
          tokens: [ 'action', '(', 0, ')', 'and', 'action', '(', 1, ')' ] 
        }
      }
      {
        input: "action 1 for 1 minute"
        result: { 
          actions: [ 
            { 
              id: 'act-test1-0', 
              token: 'action 1', 
              handler: {} # should be the dummyHandler
              after: null
              for:
                token: '1 minute',
                exprTokens: [ 1 ],
                unit: 'minute'
            } 
          ],
          tokens: [ 'action', '(', 0, ')' ] 
        }
      }
    ]

    for tc in testCases
      do (tc) ->
        it "it should parse \"#{tc.input}\"", ->
          result = ruleManager._parseRuleActions("test1", tc.input, context) 
          assert result?
          for action in result.actions
            assert action.handler instanceof env.actions.ActionHandler
            action.handler = {}
          assert(not context.hasErrors())
          assert.deepEqual result, tc.result

  describe '#parseRuleString()', ->
    context = null

    beforeEach ->
      context = ruleManager._createParseContext()


    it 'should parse: "when predicate 1 then action 1"', (finish) ->
      ruleManager._parseRuleString("test1", "test1", "when predicate 1 then action 1", context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'when predicate 1 then action 1'
        finish() 
      ).catch(finish).done()

    ruleWithForSuffix = 'when predicate 1 for 10 seconds then action 1'
    it """should parse rule with for "10 seconds" suffix: #{ruleWithForSuffix}'""", (finish) ->

      ruleManager._parseRuleString("test1", "test1", ruleWithForSuffix, context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 10 seconds'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].for.token is '10 seconds'
        assert.deepEqual rule.predicates[0].for.exprTokens, ['10']
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'when predicate 1 for 10 seconds then action 1'
        finish() 
      ).catch(finish).done()


    ruleWithHoursSuffix = "when predicate 1 for 2 hours then action 1"
    it """should parse rule with for "2 hours" suffix: #{ruleWithHoursSuffix}""", (finish) ->

      ruleManager._parseRuleString("test1", "test1", ruleWithHoursSuffix, context)
      .then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 2 hours'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].for.token is '2 hours'
        assert.deepEqual rule.predicates[0].for.exprTokens, ['2']
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'when predicate 1 for 2 hours then action 1'
        finish() 
      ).catch(finish).done()

    it 'should not detect for "42 foo" as for suffix', (finish) ->

      ruleManager._parseRuleString(
        "test1", "test1", "when predicate 1 for 42 foo then action 1", context
      ).then( (rule) -> 
        cassert rule.id is 'test1'
        cassert rule.conditionToken is 'predicate 1 for 42 foo'
        cassert rule.tokens.length > 0
        cassert rule.predicates.length is 1
        cassert rule.predicates[0].for is null
        cassert rule.actionsToken is 'action 1'
        cassert rule.string is 'when predicate 1 for 42 foo then action 1'
        finish() 
      ).catch(finish).done()


    it 'should reject wrong rule format', (finish) ->
      # Missing `then`:
      ruleManager._parseRuleString("test2", "test1", "when predicate 1 and action 1", context)
      .then( -> 
        finish new Error 'Accepted invalid rule'
      ).catch( (error) -> 
        cassert error?
        cassert error.message is 'The rule must start with "when" and contain a "then" part!'
        finish()
      ).done()

    it 'should reject unknown predicate', (finish) ->
      canDecideCalled = false
      predProvider.parsePredicate = (input, context) -> 
        cassert input is "predicate 2"
        canDecideCalled = true
        return null

      ruleManager._parseRuleString('test3', "test1", 'when predicate 2 then action 1', context)
        .then( -> 
          cassert context.hasErrors()
          cassert context.errors.length is 1
          errorMsg = context.errors[0]
          cassert(
            errorMsg is 'Could not find an provider that decides next predicate of "predicate 2".'
          )
          cassert canDecideCalled
          finish()
        ).catch(finish)
      return

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

      ruleManager._parseRuleString('test4', "test1", 'when predicate 1 then action 2', context)
        .then( -> 
          cassert context.hasErrors()
          cassert context.errors.length is 1
          errorMsg = context.errors[0]
          cassert(
            errorMsg is 'Could not find an provider that provides the next action of "action 2".'
          )
          cassert parseActionCalled
          finish()
        ).catch(finish)
      return

  notifyId = null

  # ###Tests for `addRuleByString()`
  describe '#addRuleByString()', ->

    changeHandler = null

    before ->
      predProvider.parsePredicate = (input, context) -> 
        cassert S(input).startsWith("predicate 1")
        predHandler = new DummyPredicateHandler()
        predHandler.on = (event, handler) -> 
          if event is 'change'
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

      ruleManager.addRuleByString('test5', {
        name: "test5", 
        ruleString: 'when predicate 1 then action 1'
      }).then( ->
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
        return Promise.resolve "execute action"

      setTimeout((-> changeHandler('event')), 2001)


  # ###Tests for `updateRuleByString()`
  describe '#doesRuleCondtionHold', ->

    predHandler1 = null
    predHandler2 = null

    beforeEach ->
      predHandler1 = new DummyPredicateHandler()
      predHandler1.on = (event, listener) -> 
        cassert event is 'change'
      predHandler1.getValue = => Promise.resolve true
      predHandler1.getType = => "state"

      predHandler2 = new DummyPredicateHandler()
      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
      predHandler2.getValue = => Promise.resolve true
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
        string: "when predicate 1 then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is true
      ).then( -> 
        predHandler1.getValue = => Promise.resolve false 
      ).then( -> ruleManager._evaluateConditionOfRule rule).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).catch(finish).done()

    it 'should decide trigger: predicate 1', (finish)->

      rule =
        id: "test1"
        orgCondition: "predicate 1"
        predicates: [
          id: "test1,"
          token: "trigger: predicate 1"
          type: "state"
          handler: predHandler1
          for: null
          justTrigger: yes
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "when trigger: predicate 1 then action 1"

      predHandler1.getValue = => Promise.resolve true 
      
      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is false
      ).then( ->
        knownPredicates = {
          test1: true
        }
        return ruleManager._evaluateConditionOfRule(rule, knownPredicates).then( (isTrue) ->
          cassert isTrue is false
          finish()
        )
      ).done()

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
        string: "when predicate 1 and predicate 2 then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is true
      ).then( -> 
        predHandler1.getValue = => Promise.resolve true
        predHandler2.getValue = => Promise.resolve false
      ).then( -> ruleManager._evaluateConditionOfRule rule ).then( (isTrue) ->
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
        string: "when predicate 1 or predicate 2 then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is true
      ).then( ->       
        predHandler1.getValue = => Promise.resolve true
        predHandler2.getValue = => Promise.resolve false
      ).then( -> ruleManager._evaluateConditionOfRule rule ).then( (isTrue) ->
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
          for:
            token: '1 second'
            exprTokens: [ 1 ]
            unit: 'second'
          lastChange: start
          timeAchived: false
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "when predicate 1 for 1 second then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is false
        rule.predicates[0].timeAchived = true
        return ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
          cassert isTrue is true
          finish()
        )
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
          for:
            token: '1 second'
            exprTokens: [ 1 ]
            unit: 'second'
          lastChange: start
          timeAchived: false
        ]
        tokens: [
          "predicate"
          "("
          0
          ")"
        ]
        action: "action 1"
        string: "when predicate 1 for 1 second then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is false
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
            for:
              token: '1 second'
              exprTokens: [ 1 ]
              unit: 'second'
            lastChange: start
            timeAchived: true
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
            for:
              token: '2 seconds'
              exprTokens: [ 2 ]
              unit: 'seconds'
            lastChange: start
            timeAchived: true
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
        string: "when predicate 1 for 1 second and predicate 2 for 2 seconds then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is true
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
            for:
              token: '1 second'
              exprTokens: [ 1 ]
              unit: 'second'
            lastChange: start
            timeAchived: true
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
            for:
              token: '2 seconds'
              exprTokens: [ 2 ]
              unit: 'seconds'
            lastChange: start
            timeAchived: false
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
        string: "when predicate 1 for 1 second and predicate 2 for 2 seconds then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is false
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second or predicate 2 for 2 seconds (holds)', (finish)->
      this.timeout 3000
      start = getTime()

      predHandler1.getValue = => Promise.resolve true
      predHandler2.getValue = => Promise.resolve true

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
            for:
              token: '1 second'
              exprTokens: [ 1 ]
              unit: 'second'
            lastChange: start
            timeAchived: true
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
            for:
              token: '2 seconds'
              exprTokens: [ 2 ]
              unit: 'seconds'
            lastChange: start
            timeAchived: true
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
        string: "when predicate 1 for 1 second or predicate 2 for 2 seconds then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is true
        finish()
      ).done()

    it 'should decide predicate 1 for 1 second or predicate 2 for 2 seconds (does not holds)', 
    (finish)->
      this.timeout 3000
      start = getTime()

      predHandler1.getValue = => Promise.resolve true
      predHandler2.getValue = => Promise.resolve true

      predHandler1.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          console.log "emit1"
          listener false
        , 500

      predHandler2.on = (event, listener) -> 
        cassert event is 'change'
        setTimeout ->
          console.log "emit2"
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
            for:
              token: '1 second'
              exprTokens: [ 1 ]
              unit: 'second'
            lastChange: start
            timeAchived: false
          }
          {
            id: "test2"
            token: "predicate 2"
            type: "state"
            handler: predHandler2
            for:
              token: '2 seconds'
              exprTokens: [ 2 ]
              unit: 'seconds'
            lastChange: start
            timeAchived: false
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
        string: "when predicate 1 for 1 second or predicate 2 for 2 seconds then action 1"

      rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
        .build(rule.tokens, rule.predicates)
      ruleManager._evaluateConditionOfRule(rule).then( (isTrue) ->
        cassert isTrue is false
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
          if event is 'change'
            changeListener = listener
            onCalled = i
            i++

        predHandler.getVale = => Promise.resolve true
        predHandler.getType => 'event'
        return {
          token: "predicate 2"
          nextInput: S(input).chompLeft("predicate 2").s
          predicateHandler: predHandler
        }

      actionProvider.parseAction = (input, context) -> 
        cassert S(input).startsWith("action 1")
        actHandler = new DummyActionHandler()
        actHandler.executeAction = (simulate) => Promise.resolve "execute action"
        return {
          token: "action 1"
          nextInput: S(input).chompLeft("action 1").s
          actionHandler: actHandler
        }

      ruleManager.updateRuleByString('test5', {
        name: 'test5'
        ruleString: 'when predicate 2 then action 1'
      }).then( ->
        cassert parsePredicateCalled is 1
        cassert onCalled is 2

        cassert ruleManager.rules['test5']?
        cassert ruleManager.rules['test5'].string is 'when predicate 2 then action 1'
        finish()
      ).catch(finish).done()


    it 'should react to notifies', (finish) ->
      this.timeout 3000

      actHandler.executeAction = (simulate) =>
        cassert not simulate
        finish()
        return Promise.resolve "execute action"

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
