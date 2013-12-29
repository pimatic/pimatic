assert = require "cassert"
proxyquire = require 'proxyquire'

describe "pimatic-log-reader", ->

    # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    actuators: require '../lib/actuators'
    sensors: require '../lib/sensors'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'

  tailDummy = null

  class TailDummy extends require('events').EventEmitter
      
    constructor: (@file) ->
      tailDummy = this


  logReaderWrapper = proxyquire 'pimatic-log-reader',
    tail: 
      Tail: TailDummy

  plugin = logReaderWrapper env


  sensor = null

  describe 'LogReaderPlugin', ->

    appDummy = {}
    frameworkDummy = {}

    describe '#init()', ->

      it 'should accept minimal config', ->
        config = 
          plugin: 'log-reader'
        plugin.init(appDummy, frameworkDummy, config)


    describe '#createSensor()', ->

      it 'should create a sensor', ->

        frameworkDummy.registerSensor = (s) ->
          assert s?
          assert s.id?
          assert s.name?
          sensor = s

        sensorConfig =
          id: "test-sensor"
          name: "a test sensor"
          class: "LogWatcher"
          file: "/var/log/test"
          states: ["some-state"]
          lines: [
            {
              match: "test 1"
              predicate: "test predicate 1"
              "some-state": "1"
            }
            {
              match: "test 2"
              predicate: "test predicate 2"
              "some-state": "2"
            }
          ]

        res = plugin.createSensor sensorConfig
        assert res is true
        assert tailDummy.file is "/var/log/test"
        assert sensor?

  describe 'LogWatcher', ->

    describe '#getSensorValuesNames()', ->  

      it 'should return the defined states', ->
        names = sensor.getSensorValuesNames()
        assert names?
        assert names.length is 1
        assert names[0] is 'some-state'

    describe '#getSensorValue()', ->

      it 'should return unknown', (finish) ->
        sensor.getSensorValue('some-state').then( (value) ->
          assert value is 'unknown'
          finish()
        ).catch(finish).done()

      it 'should react to log: test 1', (finish) ->
        tailDummy.emit 'line', 'test 1'
        value = sensor.getSensorValue('some-state').then( (value) ->
          assert value is '1'
          finish()
        ).catch(finish).done()

      it 'should react to log: test 2', (finish) ->
        tailDummy.emit 'line', 'test 2'
        value = sensor.getSensorValue('some-state').then( (value) ->
          assert value is '2'
          finish()
        ).catch(finish).done()

    describe '#canDecide()', ->

      it 'should decide: test predicate 1', ->
        result = sensor.canDecide 'test predicate 1'
        assert result is 'event'

      it 'should decide: test predicate 2', ->
        result = sensor.canDecide 'test predicate 2'
        assert result is 'event'

      it 'should not decide: test predicate 3', ->
        result = sensor.canDecide 'test predicate 3'
        assert result is no

    describe '#notifyWhen()', ->

      it 'should notify: test predicate 1', (finish) ->

        sensor.notifyWhen 't1', 'test predicate 1', ->
          finish()
        
        tailDummy.emit 'line', 'test 1'


