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
      {
        tokens: [1, '+', '$abc', '*', 3]
        result: "add(num(1), mul(var(abc), num(3)))"
      },
      {
        tokens: ['random', '(', ')']
        result: "fun(random, [])"
      },
      {
        tokens: ['random', '(', 1, ',', 2, ')']
        result: "fun(random, [num(1), num(2)])"
      },
      {
        tokens: [2, '*', 'random', '(', 1, ',', 2, ')']
        result: "mul(num(2), fun(random, [num(1), num(2)]))"
      },
      {
        tokens: ['random', '(', 1, ',', 2, ')', '*', 3 ]
        result: "mul(fun(random, [num(1), num(2)]), num(3))"
      }
      {
        tokens: ['random', '(', '(', 1, ')', ',', 2, ')', '*', 3 ]
        result: "mul(fun(random, [num(1), num(2)]), num(3))"
      },
      {
        tokens: ['random', '(', '(', 1, '*', 2, ')', ',', 2, ')', '*', 3 ]
        result: "mul(fun(random, [mul(num(1), num(2)), num(2)]), num(3))"
      },
      {
        tokens: ['random', '(', '(', 1, '-', 2, ')', ',', 2, ')', '*', 3 ]
        result: "mul(fun(random, [sub(num(1), num(2)), num(2)]), num(3))"
      },
      {
        tokens: ['"foo"']
        result: "str('foo')"
      },
      {
        tokens: ['"foo"', '"bar"']
        result: "con(str('foo'), str('bar'))"
      },
      {
        tokens: ['"foo"', '"bar"', '"42"']
        result: "con(con(str('foo'), str('bar')), str('42'))"
      },
      {
        tokens: ['"foo"', 1]
        result: "con(str('foo'), num(1))"
      },
      {
        tokens: ['"foo"', '(', 1, ')']
        result: "con(str('foo'), num(1))"
      },
      {
        tokens: ['"foo"', '(', 1, '*', 2, ')', '"bar"']
        result: "con(con(str('foo'), mul(num(1), num(2))), str('bar'))"
      }
    ]

    for test in tests
      do (test) =>
        tokensString = _.reduce(test.tokens, (l,r) -> "#{l} #{r}" )
        it "should build from tokens #{tokensString}", ->
          variables = {abc: {name: 'abc'}}
          functions = {random: {}}
          builder = new varsAst.ExpressionTreeBuilder(variables, functions)
          expr = builder.build(test.tokens)
          assert.equal expr.toString(), test.result