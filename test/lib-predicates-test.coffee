cassert = require "cassert"
assert = require "assert"
events = require "events"
Promise = require 'bluebird'
_ = require 'lodash'
t = require('decl-api').types
M = require '../lib/matcher'

# Setup the environment
env = require('../startup').env

createDummyParseContext = ->
  variables = {}
  functions = {}
  return M.createParseContext(variables, functions)

describe "PresencePredicateProvider", ->

  frameworkDummy = 
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.PresencePredicateProvider(frameworkDummy)

    class PresenceDummySensor extends env.devices.PresenceSensor
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        super()

    sensorDummy = new PresenceDummySensor

    frameworkDummy.deviceManager.devices =
      test: sensorDummy

  describe '#parsePredicate()', ->

    testCases = [
      {
        inputs: [
          "test is present"
          "test device is present"
          "test signals present"
          "test reports present"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.negated, no)
          assert.deepEqual(result.predicateHandler.device, sensorDummy)
      },
      {
        inputs: [
          "test is absent"
          "test is not present"
          "test device is not present"
          "test signals absent"
          "test reports absent"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.negated, yes)
          assert.deepEqual(result.predicateHandler.device, sensorDummy)
      }
    ]

    for testCase in testCases
      do (testCase) =>
        for input in testCase.inputs
          do (input) =>
            it "should parse \"#{input}\"", =>
              context = createDummyParseContext()
              result = provider.parsePredicate(input, context)
              testCase.checkOutput(input, result)

    it 'should return null if id is wrong', ->
      result = provider.parsePredicate "foo is present"
      assert(not info?)

  describe "PresencePredicateHandler", ->
    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        context = createDummyParseContext()
        result = provider.parsePredicate("test is present", context)
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()

      after ->
        predicateHandler.destroy()

      it "should notify when device is present", (finish) ->
        sensorDummy._presence = no
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, true
          finish()
        sensorDummy._setPresence yes

      it "should notify when device is absent", (finish) ->
        sensorDummy._presence = yes
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, false
          finish()
        sensorDummy._setPresence no

describe "ContactPredicateProvider", ->

  frameworkDummy = 
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.ContactPredicateProvider(frameworkDummy)

    class ContactDummySensor extends env.devices.ContactSensor
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        super()

    sensorDummy = new ContactDummySensor

    frameworkDummy.deviceManager.devices =
      test: sensorDummy

  describe '#parsePredicate()', ->

    testCases = [
      {
        inputs: [
          "test is closed"
          "test device is closed"
          "test is close"
          "test device is close"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.negated, no)
          assert.deepEqual(result.predicateHandler.device, sensorDummy)
      },
      {
        inputs: [
          "test is opened"
          "test device is opened"
          "test is open"
          "test device is open"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.negated, yes)
          assert.deepEqual(result.predicateHandler.device, sensorDummy)
      }
    ]

    for testCase in testCases
      do (testCase) =>
        for input in testCase.inputs
          do (input) =>
            it "should parse \"#{input}\"", =>
              context = createDummyParseContext()
              result = provider.parsePredicate(input, context)
              testCase.checkOutput(input, result)

    it 'should return null if id is wrong', ->
      result = provider.parsePredicate "foo is closed"
      assert(not info?)

  describe "PresencePredicateHandler", ->
    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        context = createDummyParseContext()
        result = provider.parsePredicate("test is closed", context)
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()

      after ->
        predicateHandler.destroy()

      it "should notify when device is opened", (finish) ->
        sensorDummy._contact = no
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, true
          finish()
        sensorDummy._setContact yes

      it "should notify when device is closed", (finish) ->
        sensorDummy._contact = yes
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, false
          finish()
        sensorDummy._setContact no

describe "SwitchPredicateProvider", ->

  frameworkDummy = 
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  provider = null
  switchDummy = null

  before ->
    provider = new env.predicates.SwitchPredicateProvider(frameworkDummy)

    class SwitchDummyDevice extends env.devices.SwitchActuator
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        @_state = on
        super()

    switchDummy = new SwitchDummyDevice()

    frameworkDummy.deviceManager.devices =
      test: switchDummy


  describe '#parsePredicate()', ->

    testCases = [
      {
        inputs: [
          "test is on"
          "test device is on"
          "test is turned on"
          "test is switched on"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.state, on)
          assert.deepEqual(result.predicateHandler.device, switchDummy)
      },
      {
        inputs: [
          "test is off"
          "test device is off"
          "test is turned off"
          "test is switched off"
        ]
        checkOutput: (input, result) ->
          assert result?
          assert.equal(result.token, input)
          assert.equal(result.nextInput, "")
          assert result.predicateHandler?
          assert.equal(result.predicateHandler.state, off)
          assert.deepEqual(result.predicateHandler.device, switchDummy)
      }
    ]

    for testCase in testCases
      do (testCase) =>
        for input in testCase.inputs
          do (input) =>
            it "should parse \"#{input}\"", =>
              context = createDummyParseContext()
              result = provider.parsePredicate input, context
              testCase.checkOutput(input, result)

  describe "SwitchPredicateHandler", ->

    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        context = createDummyParseContext()
        result = provider.parsePredicate "test is on", context
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()

      after ->
        predicateHandler.destroy()

      it "should notify when switch is on", (finish) ->
        switchDummy._state = off
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, on
          finish()
        switchDummy._setState on

      it "should notify when switch is off", (finish) ->
        switchDummy._state = on
        predicateHandler.once 'change', changeListener = (state)->
          assert.equal state, off
          finish()
        switchDummy._setState off


describe "DeviceAttributePredicateProvider", ->

  frameworkDummy = 
    deviceManager:
      devices: {}
      getDevices: -> _.values(@devices)

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.DeviceAttributePredicateProvider(frameworkDummy)

    class DummySensor extends env.devices.Sensor
  
      attributes:
        testvalue:
          description: "a testvalue"
          type: t.number
          unit: '°C'

      constructor: () ->
        @id = 'test'
        @name = 'test sensor'
        super()

    sensorDummy = new DummySensor()

    frameworkDummy.deviceManager.devices =
      test: sensorDummy

  describe '#parsePredicate()', ->

    comparators = 
      'is': '=='
      'is equal': '=='
      'is equal to': '=='
      'equals': '=='
      'is not': '!='
      'is less': '<'
      'less': '<'
      'less than': '<'
      'is less than': '<'
      'lower as': '<'
      'lower': '<'
      'is lower': '<'
      'below': '<'
      'is below': '<'
      'is above': '>'
      'above': '>'
      'greater': '>'
      'higher': '>'
      'greater than': '>'
      'is greater than': '>'
      'is greater or equal than': '>='
      'is equal or greater than': '>='
      'is less or equal than': '<='
      'is equal or less than': '<='

    for comp, sign of comparators
      do (comp, sign) ->
        testPredicate = "testvalue of test sensor #{comp} 42"

        it "should parse \"#{testPredicate}\"", ->
          context = createDummyParseContext()
          result = provider.parsePredicate testPredicate, context
          cassert result?
          cassert result.predicateHandler?
          predHandler = result.predicateHandler
          cassert predHandler.device.id is "test"
          cassert predHandler.comparator is sign
          cassert predHandler.attribute is 'testvalue'
          cassert predHandler.referenceValue is 42
          cassert result.token is testPredicate
          cassert result.nextInput is ""

    it "should parse predicate with unit: testvalue of test sensor is 42 °C", ->
      context = createDummyParseContext()
      result = provider.parsePredicate "testvalue of test sensor is 42 °C", context
      cassert result?
      cassert result.predicateHandler?
      predHandler = result.predicateHandler
      cassert predHandler.device.id is "test"
      cassert predHandler.comparator is "=="
      cassert predHandler.attribute is 'testvalue'
      cassert predHandler.referenceValue is 42
      cassert result.token is "testvalue of test sensor is 42 °C"
      cassert result.nextInput is ""

    it "should parse predicate with unit: testvalue of test sensor is 42 C", ->
      context = createDummyParseContext()
      result = provider.parsePredicate "testvalue of test sensor is 42 C", context
      cassert result?
      cassert result.predicateHandler?
      predHandler = result.predicateHandler
      cassert predHandler.device.id is "test"
      cassert predHandler.comparator is "=="
      cassert predHandler.attribute is 'testvalue'
      cassert predHandler.referenceValue is 42
      cassert result.token is "testvalue of test sensor is 42 C"
      cassert result.nextInput is ""

  describe "DeviceAttributePredicateHandler", ->

    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        context = createDummyParseContext()
        result = provider.parsePredicate "testvalue of test is greater than 20", context
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()

      after ->
        predicateHandler.destroy()

      it "should notify when value is greater than 20 and value is 21", (finish) ->
        predicateHandler.once 'change', (state) ->
          cassert state is true
          finish()
        sensorDummy.emit 'testvalue', 21

      it "should notify when value is greater than 20 and value is 19", (finish) ->
        predicateHandler.once 'change', (state)->
          cassert state is false
          finish()
        sensorDummy.emit 'testvalue', 19


describe "VariablePredicateProvider", ->

  frameworkDummy = new events.EventEmitter()
  frameworkDummy.variableManager = new env.variables.VariableManager(frameworkDummy, [
    {
      name: 'a'
      value: '1'
    },
    {
      name: 'b'
      value: '2'
    },
    {
      name: 'c',
      value: '3'
    }
  ])
  frameworkDummy.variableManager.init()

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.VariablePredicateProvider(frameworkDummy)

    class DummySensor extends env.devices.Sensor
  
      attributes:
        testvalue:
          description: "a testvalue"
          type: t.number
          unit: '°C'

      constructor: () ->
        @id = 'test'
        @name = 'test sensor'
        super()

      getTestvalue: -> Promise.resolve(42)

    sensorDummy = new DummySensor()
    frameworkDummy.emit 'deviceAdded', sensorDummy

  describe '#parsePredicate()', ->

    testCases = [
      {
        input: "1 + 2 < 4"
        result:
          value: true
      }
      {
        input: "1 + 3 <= 4"
        result:
          value: true
      }
      {
        input: "1 + 3 > 4"
        result:
          value: false
      }
      {
        input: "$a + 2 == 3"
        result:
          value: true
      }
      {
        input: "$a + 2 == 1 + $b"
        result:
          value: true
      }
      {
        input: "$a == $b - 1"
        result:
          value: true
      }
      {
        input: "$test.testvalue == 42"
        result:
          value: true
      }
      {
        input: "$test.testvalue == 21"
        result:
          value: false
      }
    ]

    for tc in testCases
      do (tc) =>
        it "should parse \"#{tc.input}\"", (finish) =>
          context = createDummyParseContext()
          varsAndFuns = frameworkDummy.variableManager.getVariablesAndFunctions()
          context.variables = varsAndFuns.variables
          context.functions = varsAndFuns.functions
          result = provider.parsePredicate(tc.input, context)
          assert result?
          result.predicateHandler.getValue().then( (val) =>
            assert.equal val, tc.result.value
            finish()
          ).catch(finish)


  describe "VariablePredicateHandler", ->

    describe '#on "change"', ->  
      predicateHandler = null
      after -> predicateHandler.destroy()

      it "should notify when $a is greater than 20", (finish) ->
        context = createDummyParseContext()
        varsAndFuns = frameworkDummy.variableManager.getVariablesAndFunctions()
        context.variables = varsAndFuns.variables
        context.functions = varsAndFuns.functions
        result = provider.parsePredicate "$a > 20", context
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()
        predicateHandler.once 'change', (state) ->
          cassert state is true
          finish()
        frameworkDummy.variableManager.setVariableToValue('a', '21')

    describe '#on "change"', ->  
      predicateHandler = null
      after -> predicateHandler.destroy()

      it "should notify when $test.testvalue is greater than 42", (finish) ->
        context = createDummyParseContext()
        varsAndFuns = frameworkDummy.variableManager.getVariablesAndFunctions()
        context.variables = varsAndFuns.variables
        context.functions = varsAndFuns.functions
        result = provider.parsePredicate "$test.testvalue > 42", context
        assert result?
        predicateHandler = result.predicateHandler
        predicateHandler.setup()
        predicateHandler.once 'change', (state) ->
          cassert state is true
          finish()
        sensorDummy.getTestvalue = => Promise.resolve(50)
        sensorDummy.emit 'testvalue', 50


    # describe '#on "change"', ->  
    #   predicateHandler = null
    #   after -> predicateHandler.destroy()

    #   it "should throw an error, when comparing strings", (finish) ->
    #     context = createDummyParseContext()
    #     varsAndFuns = frameworkDummy.variableManager.getVariablesAndFunctions()
    #     context.variables = varsAndFuns.variables
    #     context.functions = varsAndFuns.functions
    #     result = provider.parsePredicate "$test.testvalue > 42", context
    #     assert result?
    #     predicateHandler = result.predicateHandler
    #     predicateHandler.setup()
    #     predicateHandler.once 'change', (state) ->
    #       cassert state is true
    #       finish()
    #     sensorDummy.getTestvalue = => Promise.resolve("a")
    #     sensorDummy.attributes.testvalue.type = "string"
    #     sensorDummy.emit 'testvalue', "a"