assert = require "cassert"

describe "PresentPredicateProvider", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'


  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  beforeEach ->
    provider = new env.predicates.PresentPredicateProvider(env, frameworkDummy)

    sensorDummy = new env.devices.PresentsSensor
    sensorDummy.id = 'test'
    sensorDummy.name = 'test device'

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

    it 'should return null if id is wrong', ->
      info = provider._parsePredicate "foo is present"
      assert(not info?)

  describe '#notifyWhen()', ->

    it "should notify when device is present", (finish) ->
      sensorDummy._present = false
      success = provider.notifyWhen "test-id-1", "test is present", (state)->
        assert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy._setPresent true
      assert success

    it "should notify when device is not present", (finish) ->
      sensorDummy._present = true
      success = provider.notifyWhen "test-id-2", "test is not present", (state)->
        assert state is true
        provider.cancelNotify "test-id-2"
        finish()

      sensorDummy._setPresent false
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

describe "PresentPredicateProvider", ->

  # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    devices: require '../lib/devices'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'
    predicates: require '../lib/predicates'


  frameworkDummy = 
    devices: {}

  provider = null
  sensorDummy = null

  beforeEach ->
    provider = new env.predicates.SensorValuePredicateProvider(env, frameworkDummy)

    sensorDummy = new env.devices.Sensor
    sensorDummy.id = 'test'
    sensorDummy.name = 'test sensor'
    sensorDummy.getSensorValuesNames = -> ['test value']

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
      'greater': '>'
      'greater than': '>'
      'is greater than': '>'

    for comp, sign of comparators
      do (comp, sign) ->
        testPredicate = "test value of test sensor #{comp} 42"

        it "should parse \"#{testPredicate}\"", ->
          info = provider._parsePredicate testPredicate
          assert info?
          assert info.device.id is "test"
          assert info.comparator is sign
          assert info.sensorValueName is 'test value'
          assert info.referenceValue is 42


  describe '#notifyWhen()', ->

    it "should notify when value is greater then 20 and value is 21", (finish) ->
      success = provider.notifyWhen "test-id-1", "test value of test is greater than 20", (state)->
        assert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'test value', 21
      assert success

    it "should notify when value is greater then 20 and value is 19", (finish) ->

      success = provider.notifyWhen "test-id-1", "test value of test is greater than 20", (state)->
        assert state is false
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'test value', 20
      assert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      provider.notifyWhen "test-id-3", "test value of test is greater than 20", ->
      provider.notifyWhen "test-id-4", "test value of test is less then 20", ->

      provider.cancelNotify "test-id-3"
      assert not provider._listener['test-id-3']?
      assert provider._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      provider.cancelNotify "test-id-4"
      assert not provider._listener['test-id-3']?
      assert not provider._listener['test-id-4']?

