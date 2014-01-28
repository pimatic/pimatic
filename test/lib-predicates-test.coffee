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
      cassert info?
      cassert info.device.id is "test"
      cassert info.negated is no

    it 'should parse "test device is present"', ->
      info = provider._parsePredicate "test device is present"
      cassert info?
      cassert info.device.id is "test"
      cassert info.negated is no

    it 'should parse "test is not present"', ->
      info = provider._parsePredicate "test is not present"
      cassert info?
      cassert info.device.id is "test"
      cassert info.negated is yes

    it 'should parse "test is absent"', ->
      info = provider._parsePredicate "test is absent"
      cassert info?
      cassert info.device.id is "test"
      cassert info.negated is yes

    it 'should return null if id is wrong', ->
      info = provider._parsePredicate "foo is present"
      cassert(not info?)

  describe '#notifyWhen()', ->

    it "should notify when device is present", (finish) ->
      sensorDummy._presence = false
      success = provider.notifyWhen "test-id-1", "test is present", (state)->
        cassert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy._setPresence true
      cassert success

    it "should notify when device is not present", (finish) ->
      sensorDummy._presence = true
      success = provider.notifyWhen "test-id-2", "test is not present", (state)->
        cassert state is true
        provider.cancelNotify "test-id-2"
        finish()

      sensorDummy._setPresence false
      cassert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      provider.notifyWhen "test-id-3", "test is present", ->
      provider.notifyWhen "test-id-4", "test is not present", ->

      provider.cancelNotify "test-id-3"
      cassert not provider._listener['test-id-3']?
      cassert provider._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      provider.cancelNotify "test-id-4"
      cassert not provider._listener['test-id-3']?
      cassert not provider._listener['test-id-4']?


describe "SwitchPredicateProvider", ->

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
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is on

    it 'should parse "test device is on"', ->
      info = provider._parsePredicate "test device is on"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is on

    it 'should parse "test is off"', ->
      info = provider._parsePredicate "test is off"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is off

    it 'should parse "test is turned on"', ->
      info = provider._parsePredicate "test is turned on"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is on

    it 'should parse "test is turned off"', ->
      info = provider._parsePredicate "test is turned off"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is off

    it 'should parse "test is switched on"', ->
      info = provider._parsePredicate "test is switched on"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is on

    it 'should parse "test is switched off"', ->
      info = provider._parsePredicate "test is switched off"
      cassert info?
      cassert info.device.id is "test"
      cassert info.state is off


  describe '#notifyWhen()', ->

    it "should notify when device is turned on", (finish) ->
      switchDummy._state = off
      success = provider.notifyWhen "test-id-1", "test is turned on", (predState)->
        cassert predState is true
        provider.cancelNotify "test-id-1"
        finish()

      switchDummy._setState on
      cassert success

    it "should notify when device is turned off", (finish) ->
      switchDummy._state = on
      success = provider.notifyWhen "test-id-2", "test is turned off", (predState)->
        cassert predState is true
        provider.cancelNotify "test-id-2"
        finish()

      switchDummy._setState off
      cassert success


describe "DeviceAttributePredicateProvider", ->


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
          cassert info?
          cassert info.device.id is "test"
          cassert info.comparator is sign
          cassert info.attributeName is 'testvalue'
          cassert info.referenceValue is 42

    it "should parse predicate with unit: testvalue of test sensor is 42 °C", ->
      info = provider._parsePredicate "testvalue of test sensor is 42 °C"
      cassert info?
      cassert info.device.id is "test"
      cassert info.comparator is "=="
      cassert info.attributeName is 'testvalue'
      cassert info.referenceValue is 42

    it "should parse predicate with unit: testvalue of test sensor is 42 C", ->
      info = provider._parsePredicate "testvalue of test sensor is 42 C"
      cassert info?
      cassert info.device.id is "test"
      cassert info.comparator is "=="
      cassert info.attributeName is 'testvalue'
      cassert info.referenceValue is 42


  describe '#notifyWhen()', ->

    it "should notify when value is greater than 20 and value is 21", (finish) ->
      success = provider.notifyWhen "test-id-1", "testvalue of test is greater than 20", (state)->
        cassert state is true
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'testvalue', 21
      cassert success

    it "should notify when value is greater than 20 and value is 19", (finish) ->

      success = provider.notifyWhen "test-id-1", "testvalue of test is greater than 20", (state)->
        cassert state is false
        provider.cancelNotify "test-id-1"
        finish()

      sensorDummy.emit 'testvalue', 20
      cassert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      provider.notifyWhen "test-id-3", "testvalue of test is greater than 20", ->
      provider.notifyWhen "test-id-4", "testvalue of test is less than 20", ->

      provider.cancelNotify "test-id-3"
      cassert not provider._listener['test-id-3']?
      cassert provider._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      provider.cancelNotify "test-id-4"
      cassert not provider._listener['test-id-3']?
      cassert not provider._listener['test-id-4']?

describe "DeviceAttributePredicateAutocompleter", ->

  ac = new env.predicates.DeviceAttributePredicateAutocompleter()

  describe '#_partlyMatchPredicate()', ->

    it "should match ''", ->
      matches = ac._partlyMatchPredicate('')
      assert.deepEqual matches, {
        attribute: ''
        of: undefined
        device: undefined
        comparator: undefined
        valueAndUnit: undefined
      }

    it "should match 'attribute'", ->
      matches = ac._partlyMatchPredicate('attribute')
      assert.deepEqual matches, {
        attribute: 'attribute'
        of: undefined
        device: undefined
        comparator: undefined
        valueAndUnit: undefined
      }

    it "should match 'attribute '", ->
      matches = ac._partlyMatchPredicate('attribute ')
      assert.deepEqual matches, {
        attribute: 'attribute '
        of: undefined
        device: undefined
        comparator: undefined
        valueAndUnit: undefined
      }


    it "should match 'attribute of '", ->
      matches = ac._partlyMatchPredicate('attribute of ')
      assert.deepEqual matches, {
        attribute: 'attribute'
        of: ' of '
        device: ''
        comparator: undefined
        valueAndUnit: undefined
      }

    it "should match 'attribute of device name'", ->
      matches = ac._partlyMatchPredicate('attribute of device name')
      assert.deepEqual matches, {
        attribute: 'attribute'
        of: ' of '
        device: 'device name'
        comparator: undefined
        valueAndUnit: undefined
      }

    for comp in ['is', 'is not', 'equals', 'is less than', 'is greater than']
      do (comp) =>
        it "should match 'attribute of device name #{comp}'", ->
          matches = ac._partlyMatchPredicate("attribute of device name #{comp}")
          assert.deepEqual matches, {
            attribute: 'attribute'
            of: ' of '
            device: 'device name'
            comparator: comp
            valueAndUnit: undefined
          }

        it "should match 'attribute of device name #{comp} val'", ->
          matches = ac._partlyMatchPredicate("attribute of device name #{comp} val")
          assert.deepEqual matches, {
            attribute: 'attribute'
            of: ' of '
            device: 'device name'
            comparator: comp
            valueAndUnit: 'val'
          }