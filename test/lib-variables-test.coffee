assert = require "assert"
Promise = require 'bluebird'
events = require('events')
env = require('../startup').env

describe "VariableManager", ->
  VariableManager = require('../lib/variables')(env).VariableManager
  frameworkDummy = new events.EventEmitter()
  varManager = new VariableManager(frameworkDummy, [])
  varManager.init()

  describe '#setVariableToValue()', ->
    it "should set the variable", (finish) ->
      varManager.setVariableToValue('a', 1)
      varManager.variables['a'].getUpdatedValue().then( (value) =>
        assert.equal value, 1
        finish()
      ).catch(finish)
      return

  describe '#setVariableToExpr()', ->
    it "should set the variable to a numeric expression", (finish) ->
      varManager.setVariableToExpr('b', '2')
      varManager.variables['b'].getUpdatedValue().then( (value) =>
        assert.equal value, 2
        finish()
      ).catch(finish)
      return

    it "should set the variable to a numeric expression with vars", (finish) ->
      varManager.setVariableToExpr('c', '1*$a+10*$b')
      varManager.variables['c'].getUpdatedValue().then( (value) =>
        assert.equal value, 21
        finish()
      ).catch(finish)
      return

    it "should set the variable to a string expression", (finish) ->
      varManager.setVariableToExpr('d', '"foo"')
      varManager.variables['d'].getUpdatedValue().then( (value) =>
        assert.equal value, "foo"
        finish()
      ).catch(finish)
      return

    it "should set the variable to a string expression with vars", (finish) ->
      varManager.setVariableToExpr('e', '"$a bars"')
      varManager.variables['e'].getUpdatedValue().then( (value) =>
        assert.equal value, "1 bars"
        finish()
      ).catch(finish)
      return

    it "should set the variable to a numeric expression with vars", (finish) ->
      varManager.setVariableToExpr('f', '$c')
      varManager.variables['f'].getUpdatedValue().then( (value) =>
        assert.equal value, 21
        finish()
      ).catch(finish)
      return

    it "should detect cycles", (finish) ->
      varManager.setVariableToExpr('c', "$f")
      varManager.variables['c'].getUpdatedValue().then( (value) =>
        assert false
      ).catch( (error) =>
        assert error.message is "Dependency cycle detected for variable f"
        finish()
      ).done()
      return

    it "should set the variable to a function expression", (finish) ->
      varManager.setVariableToExpr('g', 'min(1, 2)', )
      varManager.variables['g'].getUpdatedValue().then( (value) =>
        assert.equal value, 1
        finish()
      ).catch(finish)
      return

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
      return

  describe '#evaluateNumericExpression()', ->
    it 'should calculate 1 + 2 * 3', (finish) ->
      varManager.evaluateNumericExpression([1, '+', 2, '*', 3]).then( (result) =>
        assert result, 7
        finish()
      ).catch(finish)
      return

    it 'should calculate 3 + $a * 2', (finish) ->
      varManager.evaluateNumericExpression([3, '+', '$a', '*', 2]).then( (result) =>
        assert result, 5
        finish()
      ).catch(finish)
      return

    it 'should calculate $a + $a', (finish) ->
      varManager.evaluateNumericExpression(['$a', '+', '$a']).then( (result) =>
        assert result, 2
        finish()
      ).catch(finish)
      return


  describe '#evaluateStringExpression()', ->
    it 'should interpolate "abc"', (finish) ->
      varManager.evaluateStringExpression(['"abc"']).then( (result) =>
        assert result, "abc"
        finish()
      ).catch(finish)
      return

    it 'should interpolate "abc $a"', (finish) ->
      varManager.evaluateStringExpression(['"abc "', '$a']).then( (result) =>
        assert result, "abc 1"
        finish()
      ).catch(finish)
      return

    it 'should interpolate "abc $a de"', (finish) ->
      varManager.evaluateStringExpression(['"abc "', '$a', '" de"']).then( (result) =>
        assert result, "abc 1 de"
        finish()
      ).catch(finish)
      return


  describe '#units()', ->

    before ->
      varManager.setVariableToValue('a', 1, 'V')
      varManager.setVariableToValue('b', 2, '')

    it 'should use the right unit for 1V + 2', (finish) ->
      varManager.evaluateExpressionWithUnits(["$a", "+", "$b"]).then( (result) =>
        assert result.unit is 'V'
        finish()
      ).catch(finish)
      return

    it 'should use the right unit for 1V - 2', (finish) ->
      varManager.evaluateExpressionWithUnits(["$a", "-", "$b"]).then( (result) =>
        assert result.unit is 'V'
        finish()
      ).catch(finish)
      return

    it 'should use the right unit for 1V * 2', (finish) ->
      varManager.evaluateExpressionWithUnits(["$a", "*", "$b"]).then( (result) =>
        assert result.unit is 'V'
        finish()
      ).catch(finish)
      return

    it 'should use the right unit for 1V * 1V', (finish) ->
      varManager.evaluateExpressionWithUnits(["$a", "*", "$a"]).then( (result) =>
        assert result.unit is 'V*V'
        finish()
      ).catch(finish)
      return

    it 'should use the right unit for 1V / 2', (finish) ->
      varManager.evaluateExpressionWithUnits(["$a", "/", "$b"]).then( (result) =>
        assert result.unit is 'V'
        finish()
      ).catch(finish)
      return

    it 'should use the right unit for 2 / 1V', (finish) ->
      varManager.evaluateExpressionWithUnits(["$b", "/", "$a"]).then( (result) =>
        assert result.unit is '1/V'
        finish()
      ).catch(finish)
      return

    it 'should format the value', (finish) ->
      varManager.evaluateExpressionWithUnits(["formatNumber", "(", "$a", ")"]).then( (result) =>
        assert result.value is '1V'
        assert result.unit is ''
        finish()
      ).catch(finish)
      return

    it 'should format the value with prefix', (finish) ->
      varManager.setVariableToValue('a', 1000, 'V')
      varManager.evaluateExpressionWithUnits(["formatNumber", "(", "$a", ")"]).then( (result) =>
        assert result.value is '1kV'
        assert result.unit is ''
        finish()
      ).catch(finish)
      return