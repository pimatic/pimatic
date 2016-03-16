cassert = require "cassert"
assert = require "assert"
Promise = require 'bluebird'
S = require 'string'
util = require 'util'
_ = require 'lodash'

env = require('../startup').env

describe "BoolExpressionTreeBuilder", ->

  rulesAst = require '../lib/rules-ast-builder'

  describe '#build', ->

    tests = [
      {
        tokens: ['predicate', '(', 0, ')']
        predicates: [{token: '0'}]
        result: "predicate('0')"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and', 
          'predicate', '(', 1, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}]
        result: "and(predicate('0'), predicate('1'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'or', 
          'predicate', '(', 1, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}]
        result: "or(predicate('0'), predicate('1'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'or', 
          'predicate', '(', 1, ')', 
          'and', 
          'predicate', '(', 2, ')']
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(predicate('0'), and(predicate('1'), predicate('2')))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and', 
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')']
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(and(predicate('0'), predicate('1')), predicate('2'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and',
          '['
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')'
          ']'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "and(predicate('0'), or(predicate('1'), predicate('2')))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'or',
          '['
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')'
          ']'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(predicate('0'), or(predicate('1'), predicate('2')))"
      },
      {
        tokens: [
          '['
          'predicate', '(', 0, ')', 
          'or',
          'predicate', '(', 1, ')', 
          ']'
          'and', 
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "and(or(predicate('0'), predicate('1')), predicate('2'))"
      }
      {
        tokens: [
          '['
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          ']'
          'or', 
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(and(predicate('0'), predicate('1')), predicate('2'))"
      }
      {
        tokens: [
          '[',
          '['
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          ']',
          ']'
          'or', 
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(and(predicate('0'), predicate('1')), predicate('2'))"
      }
      {
        tokens: [
          '[',
          '['
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          ']'
          'or', 
          'predicate', '(', 2, ')',
          ']'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "or(and(predicate('0'), predicate('1')), predicate('2'))"
      },
      {
        tokens: [
          '['
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')'
          ']'
          'or', 
          'predicate', '(', 3, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}, {token: '3'}]
        result: "or(or(and(predicate('0'), predicate('1')), predicate('2')), predicate('3'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and if',
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}, {token: '3'}]
        result: "andif(predicate('0'), or(predicate('1'), predicate('2')))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'or when',
          'predicate', '(', 1, ')', 
          'or when',
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "orwhen(orwhen(predicate('0'), predicate('1')), predicate('2'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'or',
          'predicate', '(', 1, ')', 
          'or when',
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "orwhen(or(predicate('0'), predicate('1')), predicate('2'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          'or when',
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "orwhen(and(predicate('0'), predicate('1')), predicate('2'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and if',
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')',
          'or when', 
          'predicate', '(', 3, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}, {token: '3'}]
        result: "orwhen(andif(predicate('0'), or(predicate('1'), predicate('2'))), predicate('3'))"
      },
      {
        tokens: [
          'predicate', '(', 0, ')', 
          'and if',
          'predicate', '(', 1, ')', 
          'or', 
          'predicate', '(', 2, ')',
          'or when', 
          'predicate', '(', 3, ')'
          'or', 
          'predicate', '(', 4, ')',
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}, {token: '3'}, {token: '4'}]
        result: "orwhen(andif(predicate('0'), or(predicate('1'), predicate('2'))), " +
          "or(predicate('3'), predicate('4')))"
      }
      {
        tokens: [
          '['
          'predicate', '(', 0, ')', 
          'and',
          'predicate', '(', 1, ')', 
          ']'
          'or when', 
          'predicate', '(', 2, ')'
        ]
        predicates: [{token: '0'}, {token: '1'}, {token: '2'}]
        result: "orwhen(and(predicate('0'), predicate('1')), predicate('2'))"
      }
    ]

    for test in tests
      do (test) =>
        tokensString = _.reduce(test.tokens, (l,r) -> "#{l} #{r}" )
        it "should build from tokens #{tokensString}", ->
          builder = new rulesAst.BoolExpressionTreeBuilder()
          expr = builder.build(test.tokens, test.predicates)
          assert.equal expr.toString(), test.result