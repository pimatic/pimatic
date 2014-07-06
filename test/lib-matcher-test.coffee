assert = require "assert"
Promise = require 'bluebird'
M = require '../lib/matcher'

env = require('../startup').env

describe "Matcher", ->

  describe '#match()', ->

    testCases = [
      {
        input: 
          token: "some test string"
          pattern: 'some'
        result: 
          match: "some"
          nextInput: ' test string'
      }
      {
        input: 
          token: "some test string"
          pattern: ["foo", "some"]
        result: 
          match: "some"
          nextInput: ' test string'
      }

    ]

    for tc in testCases
      do (tc) =>
        it "should have matches in #{tc.input.token}", ->
          m = M(tc.input.token).match(tc.input.pattern)
          assert.deepEqual(m.getFullMatch(), tc.result.match)
          assert.deepEqual(m.input, tc.result.nextInput)

  describe '#matchNumericExpression()', ->

    it "should match 1", (finish) ->
      M("1").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1'])
        finish()
      )

    it "should match 1 + 2", (finish) ->
      M("1 + 2").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2'])
        finish()
      )

    it "should match 1 + 2 * 3", (finish) ->
      M("1 + 2 * 3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2', '*', '3'])
        finish()
      )

    it "should match $abc", (finish) ->
      M("$abc").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc'])
        finish()
      )

    it "should match $abc + 2 * 3", (finish) ->
      M("$abc + 2 * 3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc','+','2', '*', '3'])
        finish()
      )

    it "should match 1 + $abc * 3", (finish) ->
      M("1 + $abc * 3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','$abc', '*', '3'])
        finish()
      )

    it "should match 1+2", (finish) ->
      M("1+2").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2'])
        finish()
      )

    it "should match 1+2*3", (finish) ->
      M("1+2*3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2', '*', '3'])
        finish()
      )

    it "should match $abc with given var list", (finish) ->
      M("$abc").matchNumericExpression(['abc'], (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc'])
        finish()
      )

    it "should match $abc+2*3", (finish) ->
      M("$abc+2*3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc','+','2', '*', '3'])
        finish()
      )

    it "should match 1+$abc*3", (finish) ->
      M("1+$abc*3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','$abc', '*', '3'])
        finish()
      )

    it "should match (1+2*3)", (finish) ->
      M("(1+2*3)").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', '*', '3', ')'])
        finish()
      )

    it "should match ( 1 + 2 * 3 )", (finish) ->
      M("( 1 + 2 * 3 )").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', '*', '3', ')'])
        finish()
      )

    it "should match (1 + 2) * 3", (finish) ->
      M("(1 + 2) * 3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', ')', '*', '3'])
        finish()
      )

    it "should match (1+2)*3", (finish) ->
      M("(1+2)*3").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', ')', '*', '3'])
        finish()
      )

    it "should match 1+(2*3)", (finish) ->
      M("1+(2*3)").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','(', '2', '*', '3', ')'])
        finish()
      )

    it "should match (1)", (finish) ->
      M("(1)").matchNumericExpression( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1', ')'])
        finish()
      )

  describe '#matchStringWithVars()', ->

    it "should match \"foo\"", (finish) ->
      M('"foo"').matchStringWithVars( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo"'])
        finish()
      )

    it "should match the empty string", (finish) ->
      M('""').matchStringWithVars( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""'])
        finish()
      )

    it "should match \"foo $bar\"", (finish) ->
      M('"foo $bar"').matchStringWithVars( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo "', '$bar', '""'])
        finish()
      )

    it "should match \"foo $bar test\"", (finish) ->
      M('"foo $bar test"').matchStringWithVars( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo "', '$bar', '" test"'])
        finish()
      )

    it "should match \"$bar foo test\"", (finish) ->
      M('"$bar foo test"').matchStringWithVars( (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""', '$bar', '" foo test"'])
        finish()
      )

  describe '#matchString()', ->

    it "should match \"foo\"", (finish) ->
      M('"foo"').matchString( (m, str) =>
        assert m?
        assert.deepEqual(str, 'foo')
        finish()
      )

    it "should match the empty string", (finish) ->
      M('""').matchString( (m, str) =>
        assert m?
        assert.deepEqual(str, '')
        finish()
      )