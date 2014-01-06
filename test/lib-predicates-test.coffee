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
      assert info.present is yes

    it 'should parse "test device is present"', ->
      info = provider._parsePredicate "test device is present"
      assert info?
      assert info.device.id is "test"
      assert info.present is yes

    it 'should parse "test is not present"', ->
      info = provider._parsePredicate "test is not present"
      assert info?
      assert info.device.id is "test"
      assert info.present is no

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

