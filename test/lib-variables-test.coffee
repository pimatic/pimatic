assert = require "assert"
Q = require 'q'
events = require('events')
env = require('../startup').env

describe "VariableManager", ->
  VariableManager = require('../lib/variables')(env).VariableManager
  frameworkDummy = new events.EventEmitter()
  varManager = new VariableManager(frameworkDummy, [])

  describe '#setVariableToValue()', ->
    it "should set the variable", (finish) ->
      varManager.setVariableToValue('a', 1)
      varManager.variables['a'].getUpdatedValue().then( (value) =>
        assert.equal value, 1
        finish()
      ).catch(finish)

  describe '#setVariableToExpr()', ->
    it "should set the to a numeric expression", (finish) ->
      varManager.setVariableToExpr('b', '2')
      varManager.variables['b'].getUpdatedValue().then( (value) =>
        assert.equal value, 2
        finish()
      ).catch(finish)

    it "should set the to a numeric expression with vars", (finish) ->
      varManager.setVariableToExpr('c', '1*$a+10*$b')
      varManager.variables['c'].getUpdatedValue().then( (value) =>
        assert.equal value, 21
        finish()
      ).catch(finish)

    it "should set the to a string expression", (finish) ->
      varManager.setVariableToExpr('d', '"foo"')
      varManager.variables['d'].getUpdatedValue().then( (value) =>
        assert.equal value, "foo"
        finish()
      ).catch(finish)

    it "should set the to a string expression with vars", (finish) ->
      varManager.setVariableToExpr('e', '"$a bars"')
      varManager.variables['e'].getUpdatedValue().then( (value) =>
        assert.equal value, "1 bars"
        finish()
      ).catch(finish)

    it "should detect cycles", (finish) ->
      varManager.setVariableToExpr('f', "$f")
      varManager.variables['f'].getUpdatedValue().then( (value) =>
        assert false
      ).catch( (error) =>
        assert error.message is "Dependency cycle detected for variable f"
        finish()
      ).done()

  describe '#isVariableDefined()', ->
    it "should return true", ->
      isDefined = varManager.isVariableDefined('a')
      assert isDefined

  describe '#getVariableValue()', ->
    it "get the var value", (finish) ->
      varManager.getVariableUpdatedValue('a').then( (value) =>
        assert.equal value, 1
        finish()
      ).catch(finish)

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

    it 'should calculate $a + $a', (finish) ->
      varManager.evaluateNumericExpression(['$a', '+', '$a']).then( (result) =>
        assert result, 2
        finish()
      ).catch(finish)


  describe '#evaluateStringExpression()', ->
    it 'should interpolate "abc"', (finish) ->
      varManager.evaluateStringExpression(['"abc"']).then( (result) =>
        assert result, "abc"
        finish()
      ).catch(finish)

    it 'should interpolate "abc $a"', (finish) ->
      varManager.evaluateStringExpression(['"abc"', '$a']).then( (result) =>
        assert result, "abc 1"
        finish()
      ).catch(finish)







