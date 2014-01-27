assert = require "cassert"

describe "PresencePredicateProvider", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'


  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  beforeEach ->
    provider = new env.predicates.PresencePredicateProvider(env, frameworkDummy)

    class PresenceDummySensor extends env.devices.PresenceSensor
      constructor: () ->
        @id = 'test'
        @name = 'test device'
        super()

    sensorDummy = new PresenceDummySensor

    frameworkDummy.devices =
      test: sensorDummy

  describe '#_parsePredicate()', ->

    it 'should parse "test is present"', ->
      info = provider._parsePredicate "test is present"
      assert info?
      assert info.device.id is "test"
      assert info.negated is no

    it 'should parse "test device is present"', ->
      info = provider._parsePredicate "test device is present"
      assert info?
      assert info.device.id is "test"
      assert info.negated is no

    it 'should parse "test is not present"', ->
      info = provider._parsePredicate "test is not present"
      assert info?
      assert info.device.id is "test"
      assert info.negated is yes

    it 'should parse "test is absent"', ->
      info = provider._parsePredicate "test is absent"
      assert info?
      assert info.device.id is "test"
      assert info.negated is yes

    it 'should return null if id is wrong', ->
      info = provider._parsePredicate "foo is present"
      assert(not info?)

  describe '#notifyWhen()', ->

    it "should notify when device is present", (finish) ->
      sensorDummy._presence = false
      success = provider.notifyWhen "test-id-1", "test is present", (state)->
        assert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy._setPresence true
      assert success

    it "should notify when device is not present", (finish) ->
      sensorDummy._presence = true
      success = provider.notifyWhen "test-id-2", "test is not present", (state)->
        assert state is true
        provider.cancelNotify "test-id-2"
        finish()

      sensorDummy._setPresence false
      assert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      provider.notifyWhen "test-id-3", "test is present", ->
      provider.notifyWhen "test-id-4", "test is not present", ->

      provider.cancelNotify "test-id-3"
      assert not provider._listener['test-id-3']?
      assert provider._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      provider.cancelNotify "test-id-4"
      assert not provider._listener['test-id-3']?
      assert not provider._listener['test-id-4']?


describe "SwitchPredicateProvider", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'


  frameworkDummy = 
    devices: {}

  provider = null
  switchDummy = null

  beforeEach ->
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

  describe '#_parsePredicate()', ->

    it 'should parse "test is on"', ->
      info = provider._parsePredicate "test is on"
      assert info?
      assert info.device.id is "test"
      assert info.state is on

    it 'should parse "test device is on"', ->
      info = provider._parsePredicate "test device is on"
      assert info?
      assert info.device.id is "test"
      assert info.state is on

    it 'should parse "test is off"', ->
      info = provider._parsePredicate "test is off"
      assert info?
      assert info.device.id is "test"
      assert info.state is off

    it 'should parse "test is turned on"', ->
      info = provider._parsePredicate "test is turned on"
      assert info?
      assert info.device.id is "test"
      assert info.state is on

    it 'should parse "test is turned off"', ->
      info = provider._parsePredicate "test is turned off"
      assert info?
      assert info.device.id is "test"
      assert info.state is off

    it 'should parse "test is switched on"', ->
      info = provider._parsePredicate "test is switched on"
      assert info?
      assert info.device.id is "test"
      assert info.state is on

    it 'should parse "test is switched off"', ->
      info = provider._parsePredicate "test is switched off"
      assert info?
      assert info.device.id is "test"
      assert info.state is off


  describe '#notifyWhen()', ->

    it "should notify when device is turned on", (finish) ->
      switchDummy._state = off
      success = provider.notifyWhen "test-id-1", "test is turned on", (predState)->
        assert predState is true
        provider.cancelNotify "test-id-1"
        finish()

      switchDummy._setState on
      assert success

    it "should notify when device is turned off", (finish) ->
      switchDummy._state = on
      success = provider.notifyWhen "test-id-2", "test is turned off", (predState)->
        assert predState is true
        provider.cancelNotify "test-id-2"
        finish()

      switchDummy._setState off
      assert success


describe "DeviceAttributePredicateProvider", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'


  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  beforeEach ->
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

  describe '#_parsePredicate()', ->

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
          info = provider._parsePredicate testPredicate
          assert info?
          assert info.device.id is "test"
          assert info.comparator is sign
          assert info.attributeName is 'testvalue'
          assert info.referenceValue is 42

    it "should parse predicate with unit: testvalue of test sensor is 42 °C", ->
      info = provider._parsePredicate "testvalue of test sensor is 42 °C"
      assert info?
      assert info.device.id is "test"
      assert info.comparator is "=="
      assert info.attributeName is 'testvalue'
      assert info.referenceValue is 42

    it "should parse predicate with unit: testvalue of test sensor is 42 C", ->
      info = provider._parsePredicate "testvalue of test sensor is 42 C"
      assert info?
      assert info.device.id is "test"
      assert info.comparator is "=="
      assert info.attributeName is 'testvalue'
      assert info.referenceValue is 42


  describe '#notifyWhen()', ->

    it "should notify when value is greater than 20 and value is 21", (finish) ->
      success = provider.notifyWhen "test-id-1", "testvalue of test is greater than 20", (state)->
        assert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'testvalue', 21
      assert success

    it "should notify when value is greater than 20 and value is 19", (finish) ->

      success = provider.notifyWhen "test-id-1", "testvalue of test is greater than 20", (state)->
        assert state is false
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'testvalue', 20
      assert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      provider.notifyWhen "test-id-3", "testvalue of test is greater than 20", ->
      provider.notifyWhen "test-id-4", "testvalue of test is less than 20", ->

      provider.cancelNotify "test-id-3"
      assert not provider._listener['test-id-3']?
      assert provider._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      provider.cancelNotify "test-id-4"
      assert not provider._listener['test-id-3']?
      assert not provider._listener['test-id-4']?

