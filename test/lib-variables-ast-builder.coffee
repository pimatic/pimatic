cassert = require "cassert"
assert = require "assert"
Promise = require 'bluebird'
S = require 'string'
util = require 'util'
_ = require 'lodash'

env = require('../startup').env

describe "ExpressionTreeBuilder", ->

  varsAst = require '../lib/variables-ast-builder'

  describe '#build', ->

    tests = [
      {
        tokens: [1]
        result: "num(1)"
      },
      {
        tokens: [1, '+', 2]
        result: "add(num(1), num(2))"
      },
      {
        tokens: [1, '+', 2, '-', 3]
        result: "sub(add(num(1), num(2)), num(3))"
      },
      {
        tokens: [1, '*', 2, '+', 3]
        result: "add(mul(num(1), num(2)), num(3))"
      },
      {
        tokens: [1, '+', 2, '*', 3]
        result: "add(num(1), mul(num(2), num(3)))"
      },
      {
        tokens: ['(', 1, '+', 2, ')', '*', 3]
        result: "mul(add(num(1), num(2)), num(3))"
      },
      {
        tokens: ['(', '(', 1, '+', 2, ')', '*', 3, ')']
        result: "mul(add(num(1), num(2)), num(3))"
      }
      {
        tokens: ['(', '(', '(', 1, '+', 2, ')', ')', '*', 3, ')']
        result: "mul(add(num(1), num(2)), num(3))"
      }
    ]

    for test in tests
      do (test) =>
        tokensString = _.reduce(test.tokens, (l,r) -> "#{l} #{r}" )
        it "should build from tokens #{tokensString}", ->
          builder = new varsAst.ExpressionTreeBuilder()
          expr = builder.build(test.tokens, test.variables, test.functions)
          assert.equal expr.toString(), test.result