cassert = require "cassert"
assert = require "assert"

# Setup the environment
env =
  logger: require '../lib/logger'
  devices: require '../lib/devices'
  rules: require '../lib/rules'
  plugins: require '../lib/plugins'
  predicates: require '../lib/predicates'


describe "PresencePredicateProvider", ->

  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.PresencePredicateProvider(env, frameworkDummy)

    class PresenceDummySensor extends env.devices.PresenceSensor
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        super()

    sensorDummy = new PresenceDummySensor

    frameworkDummy.devices =
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
          result.predicateHandler.destroy()
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
          result.predicateHandler.destroy()
      }
    ]

    for testCase in testCases
      do (testCase) =>
        for input in testCase.inputs
          do (input) =>
            it "should parse \"#{input}\"", =>
              result = provider.parsePredicate input
              testCase.checkOutput(input, result)

    it 'should return null if id is wrong', ->
      result = provider.parsePredicate "foo is present"
      assert(not info?)

  describe "PresencePredicateHandler", ->
    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        result = provider.parsePredicate "test is present"
        assert result?
        predicateHandler = result.predicateHandler

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

describe "SwitchPredicateProvider", ->

  frameworkDummy = 
    devices: {}

  provider = null
  switchDummy = null

  before ->
    provider = new env.predicates.SwitchPredicateProvider(env, frameworkDummy)

    class SwitchDummyDevice extends env.devices.SwitchActuator
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        @_state = on
        super()

    switchDummy = new SwitchDummyDevice

    frameworkDummy.devices =
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
          result.predicateHandler.destroy()
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
          result.predicateHandler.destroy()
      }
    ]

    for testCase in testCases
      do (testCase) =>
        for input in testCase.inputs
          do (input) =>
            it "should parse \"#{input}\"", =>
              result = provider.parsePredicate input
              testCase.checkOutput(input, result)

  describe "SwitchPredicateHandler", ->

    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        result = provider.parsePredicate "test is on"
        assert result?
        predicateHandler = result.predicateHandler

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


  context = {
    addHint: ->
    addMatch: (@match) ->
  }

  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  before ->
    provider = new env.predicates.DeviceAttributePredicateProvider(env, frameworkDummy)

    class DummySensor extends env.devices.Sensor
  
      attributes:
        testvalue:
          description: "a testvalue"
          type: Number
          unit: '°C'

      constructor: () ->
        @id = 'test'
        @name = 'test sensor'
        super()

    sensorDummy = new DummySensor()

    frameworkDummy.devices =
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

    for comp, sign of comparators
      do (comp, sign) ->
        testPredicate = "testvalue of test sensor #{comp} 42"

        it "should parse \"#{testPredicate}\"", ->
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
          predHandler.destroy()

    it "should parse predicate with unit: testvalue of test sensor is 42 °C", ->
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
      predHandler.destroy()

    it "should parse predicate with unit: testvalue of test sensor is 42 C", ->
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
      predHandler.destroy()

  describe "SwitchPredicateHandler", ->

    describe '#on "change"', ->  
      predicateHandler = null
      before ->
        result = provider.parsePredicate "testvalue of test is greater than 20"
        assert result?
        predicateHandler = result.predicateHandler

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
