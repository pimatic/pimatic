assert = require "assert"
Q = require 'q'
events = require('events')
env = require('../startup').env

describe "VariableManager", ->
  VariableManager = require('../lib/variables')(env).VariableManager
  frameworkDummy = new events.EventEmitter()
  varManager = new VariableManager(frameworkDummy)

  describe '#setVariable()', (finish) ->
    it "should set the variable", ->
      varManager.setVariable('a', 1)
      varManager.variables['a'].getValue().then( (value) =>
        assert.equal value, 1
        finish()
      )

  describe '#isVariableDefined()', ->
    it "should return true", ->
      isDefined = varManager.isVariableDefined('a')
      assert isDefined

  describe '#getVariableValue()', (finish) ->
    it "get the var value", ->
      varManager.getVariableValue('a').then( (value) =>
        assert.equal value, 1
        finish()
      )

  describe '#evaluateNumericExpression()', ->
    it 'should calculate 1 + 2 * 3', (finish) ->
      varManager.evaluateNumericExpression(['1', '+', '2', '*', '3']).then( (result) =>
        assert result, 7
        finish()
      ).catch(finish)

    it 'should calculate 3 + $a * 2', (finish) ->
      varManager.evaluateNumericExpression(['3', '+', '$a', '*', '2']).then( (result) =>
        assert result, 5
        finish()
      ).catch(finish)







