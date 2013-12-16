assert = require "cassert"
Q = require 'q'

describe "RuleManager", ->

    # Setup the environment
  env =
    logger: require '../lib/logger'
    helper: require '../lib/helper'
    actuators: require '../lib/actuators'
    sensors: require '../lib/sensors'
    rules: require '../lib/rules'
    plugins: require '../lib/plugins'

  ruleManager = null

  before ->
    class DummySensor extends env.sensors.Sensor
      type: 'unknwon'
      name: 'test'
      getSensorValuesNames: -> []
      getSensorValue: (name) -> throw new Error("no name available")
      canDecide: (predicate) -> 
        assert predicate is "predicate 1"
        return true
      isTrue: (id, predicate) -> Q.fcall -> false
      notifyWhen: (id, predicate, callback) -> true
      cancelNotify: (id) -> true

    class DummyActionHandler
      executeAction: (actionString, simulate) =>
        assert actionString is "action 1"
        return Q.fcall -> "action 1 executed"


    serverDummy = 
      sensors: [new DummySensor]
    ruleManager = new env.rules.RuleManager serverDummy, []
    ruleManager.actionHandlers = [new DummyActionHandler]

  describe '#parseRuleString()', ->

    it 'should parse valid rule"', (done) ->
      ruleManager.parseRuleString("test1", "if predicate 1 then action 1")
        .then( -> done() ).catch( (e) -> done e )


