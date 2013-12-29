assert = require "cassert"

describe "pimatic-ping", ->

    # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    actuators: require '../lib/actuators'
    sensors: require '../lib/sensors'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'

  plugin = (require 'pimatic-ping') env
  PingPresents = plugin.PingPresents
  sessionDummy = null
  sensor = null

  beforeEach ->
    sessionDummy = 
      pingHost: (host, callback) ->
    config =
      id: 'test'
      name: 'test device'
      host: 'localhost'
      delay: 200
    sensor = new PingPresents(config, sessionDummy)

  describe '#_parsePredicate()', ->

    it 'should parse "test is present"', ->
      info = sensor._parsePredicate "test is present"
      assert info?
      assert info.deviceId is "test"
      assert info.present is yes

    it 'should parse "test device is present"', ->
      info = sensor._parsePredicate "test device is present"
      assert info?
      assert info.deviceId is "test"
      assert info.present is yes

    it 'should parse "test is not present"', ->
      info = sensor._parsePredicate "test is not present"
      assert info?
      assert info.deviceId is "test"
      assert info.present is no

    it 'should return null if id is wrong', ->
      info = sensor._parsePredicate "foo is present"
      assert(not info?)

  describe '#notifyWhen()', ->

    it "should notify when device is present", (finish) ->
      sessionDummy.pingHost = (host, callback) ->
        assert host is "localhost"
        setTimeout ->
          callback null, host
        ,22

      success = sensor.notifyWhen "test-id-1", "test is present", (state)->
        assert state is true
        sensor.cancelNotify "test-id-1"
        finish()
      assert success

    it "should notify when device is not present", (finish) ->
      sessionDummy.pingHost = (host, callback) ->
        assert host is "localhost"
        setTimeout ->
          callback new Error('foo'), host
        ,22

      success = sensor.notifyWhen "test-id-2", "test is not present", (state)->
        assert state is true
        sensor.cancelNotify "test-id-2"
        finish()
      assert success

  describe '#cancelNotify()', ->

    it "should cancel notify test-id-3", ->

      sensor.notifyWhen "test-id-3", "test is present", ->
      sensor.notifyWhen "test-id-4", "test is not present", ->

      sensor.cancelNotify "test-id-3"
      assert not sensor._listener['test-id-3']?
      assert sensor._listener['test-id-4']?

    it "should cancel notify test-id-4", ->

      sensor.cancelNotify "test-id-4"
      assert not sensor._listener['test-id-3']?
      assert not sensor._listener['test-id-4']?

