assert = require "assert"
Q = require 'q'
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
          match: ["some"]
          nextTokens: [' test string']
      }
      {
        input: 
          token: "some test string"
          pattern: ["foo", "some"]
        result: 
          match: ["some"]
          nextTokens: [' test string']
      }

    ]

    for tc in testCases
      do (tc) =>
        it "should have matches in #{tc.input.token}", ->
          m = M(tc.input.token).match(tc.input.pattern)
          assert.deepEqual(m.getFullMatches(), tc.result.match)
          assert.deepEqual(m.inputs, tc.result.nextTokens)

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