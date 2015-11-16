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
    varsAndFuns = {
      variables: {
        'abc': {}
      },
      functions: {
        'min': {
          argc: 2
        }
      }
    }
    it "should match 1", (finish) ->
      M("1").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1'])
        finish()
      )

    it "should match 1 + 2", (finish) ->
      M("1 + 2").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2'])
        finish()
      )

    it "should match 1 + 2 * 3", (finish) ->
      M("1 + 2 * 3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2', '*', '3'])
        finish()
      )

    it "should match $abc", (finish) ->
      M("$abc").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc'])
        finish()
      )

    it "should match $abc + 2 * 3", (finish) ->
      M("$abc + 2 * 3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc','+','2', '*', '3'])
        finish()
      )

    it "should match 1 + $abc * 3", (finish) ->
      M("1 + $abc * 3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','$abc', '*', '3'])
        finish()
      )

    it "should match 1+2", (finish) ->
      M("1+2").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2'])
        finish()
      )

    it "should match 1+2*3", (finish) ->
      M("1+2*3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','2', '*', '3'])
        finish()
      )

    it "should match $abc with given var list", (finish) ->
      M("$abc").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc'])
        finish()
      )

    it "should match $abc+2*3", (finish) ->
      M("$abc+2*3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['$abc','+','2', '*', '3'])
        finish()
      )

    it "should match 1+$abc*3", (finish) ->
      M("1+$abc*3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','$abc', '*', '3'])
        finish()
      )

    it "should match (1+2*3)", (finish) ->
      M("(1+2*3)").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', '*', '3', ')'])
        finish()
      )

    it "should match ( 1 + 2 * 3 )", (finish) ->
      M("( 1 + 2 * 3 )").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', '*', '3', ')'])
        finish()
      )

    it "should match (1 + 2) * 3", (finish) ->
      M("(1 + 2) * 3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', ')', '*', '3'])
        finish()
      )

    it "should match (1+2)*3", (finish) ->
      M("(1+2)*3").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1','+','2', ')', '*', '3'])
        finish()
      )

    it "should match 1+(2*3)", (finish) ->
      M("1+(2*3)").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['1','+','(', '2', '*', '3', ')'])
        finish()
      )

    it "should match (1)", (finish) ->
      M("(1)").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['(', '1', ')'])
        finish()
      )

    it "should match min(1, 2)", (finish) ->
      functions = {
        min: {}
      }
      M("min(1, 2)").matchNumericExpression(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['min', '(', '1', ',', '2', ')'])
        finish()
      )


  describe '#matchStringWithVars()', ->
    varsAndFuns = {
      variables: {
        'bar': {}
      },
      functions: {
        'min': {
          argc: 2
        }
      }
    }
    it "should match \"foo\"", (finish) ->
      M('"foo"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo"'])
        finish()
      )

    it "should match the empty string", (finish) ->
      M('""').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""'])
        finish()
      )

    it "should match \"foo $bar\"", (finish) ->
      M('"foo $bar"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo "', '$bar', '""'])
        finish()
      )

    it "should match \"foo $bar test\"", (finish) ->
      M('"foo $bar test"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo "', '$bar', '" test"'])
        finish()
      )

    it "should match \"$bar foo test\"", (finish) ->
      M('"$bar foo test"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""', '$bar', '" foo test"'])
        finish()
      )

    it "should match \"foo {$bar}\"", (finish) ->
      M('"foo {$bar}"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"foo "', '(', '$bar', ')', '""'])
        finish()
      )

    it "should match \"{$bar} foo\"", (finish) ->
      M('"{$bar} foo"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""', '(', '$bar', ')', '" foo"'])
        finish()
      )

    it "should match \"{min(1, 2)} foo\"", (finish) ->
      M('"{min(1, 2)} foo"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""', '(', 'min', '(', 1, ',' , 2, ')', ')', '" foo"'])
        finish()
      )

    it "should match \"{ min(1, 2) + 1 }\"", (finish) ->
      M('"{ min(1, 2) + 1 } foo"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['""', '(', 'min',  '(', 1, ',' , 2, ')', '+', 1, ')', '" foo"'])
        finish()
      )

    it "should handle escaped quotes \"some \\\" quote\"", (finish) ->
      M('"some \\" quote"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some " quote"'])
        finish()
      )

    it "should handle escaped sollar sign \"some \\$abc dollar\"", (finish) ->
      M('"some \\$abc dollar"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some $abc dollar"'])
        finish()
      )

    it "should handle escaped backslash \"some \\\\ back\"", (finish) ->
      M('"some \\\\ back"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some \\ back"'])
        finish()
      )

    it "should handle escaped brackets and other chars: \"\\{ \\} \\$\"", (finish) ->
      M('"\\{ \\} \\$"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"{ } $"'])
        finish()
      )

    it "should handle escaped backslash at end \"some \\\\\"", (finish) ->
      M('"some \\\\"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some \\"'])
        finish()
      )


    it "should handle escaped backslash at end \"some \\\\\"", (finish) ->
      M('"echo \\"abc\\" | mailx -s \\"def\\""').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"echo "abc" | mailx -s "def""'])
        finish()
      )

    it "should handle new line \"some \\n text", (finish) ->
      M('"some \\n text"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some \n text"'])
        finish()
      )

    it "should not handle as new line \"some \\\\n text", (finish) ->
      M('"some \\\\n text"').matchStringWithVars(varsAndFuns, (m, tokens) =>
        assert m?
        assert.deepEqual(tokens, ['"some \\n text"'])
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