###
variables AST Builder
===========
Builds a Abstract Syntax Tree (AST) from a variable expression token sequence.
###

 
assert = require 'cassert'
util = require 'util'
Promise = require 'bluebird'
_ = require 'lodash'
S = require 'string'

class Expression

class AddExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val1) => 
      @right.evaluate(cache).then( (val2) => val1 + val2 )
    )
  toString: -> "add(#{@left.toString()}, #{@right.toString()})"

class SubExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val1) => 
      @right.evaluate(cache).then( (val2) => val1 - val2 )
    )
  toString: -> "sub(#{@left.toString()}, #{@right.toString()})"

class MulExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val1) => 
      @right.evaluate(cache).then( (val2) => val1 * val2 )
    )
  toString: -> "mul(#{@left.toString()}, #{@right.toString()})"

class DivExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val1) => 
      @right.evaluate(cache).then( (val2) => val1 / val2 )
    )
  toString: -> "div(#{@left.toString()}, #{@right.toString()})"

class NumberExpression extends Expression
  constructor: (@value) -> #nop
  evaluate: (cache) -> Promise.resolve @value
  toString: -> "num(#{@value})"

class VariableExpression extends Expression
  constructor: (@variable) -> #nop
  evaluate: (cache) -> @variable.getValue()
  toString: -> "var(#{@variable.name})"


class ExpressionTreeBuilder
  _nextToken: ->
    if @pos < @tokens.length
      @token = @tokens[@pos++]
    else
      @token = ''
  build: (@tokens, @predicates) ->
    @pos = 0
    @_nextToken()
    return @_buildExpression()

  _buildExpression: () ->
    left = @_buildTerm()
    return @_buildExpressionPrime(left)

  _buildExpressionPrime: (left) ->
    switch @token
      when '+'
        @_nextToken()
        right = @_buildTerm()
        return @_buildExpressionPrime(new AddExpression(left, right))
      when '-'
        @_nextToken()
        right = @_buildTerm()
        return @_buildExpressionPrime(new SubExpression(left, right))
      when ')', ''
        return left
      else assert false

  _buildTerm: () ->
    left = @_buildFactor()
    return @_buildTermPrime(left)

  _buildTermPrime: (left) ->
    switch @token
      when '*'
        @_nextToken()
        right = @_buildFactor()
        return @_buildTermPrime(new MulExpression(left, right))
      when '/'
        @_nextToken()
        right = @_buildFactor()
        return @_buildTermPrime(new DivExpression(left, right))
      when '+', '-', ')', ''
        return left
      else assert false

  _buildFactor: () ->
    switch 
      when @token is '('
        @_nextToken()
        expr = @_buildExpression()
        assert @token is ')'
        @_nextToken()
        return expr
      when typeof @token is "number"
        numberExpr = new NumberExpression(@token)
        @_nextToken()
        return numberExpr
      when @token.length > 0 and @token[0] is '$'
        varExpr = new VariableExpression(@token)
        @_nextToken()
        return varExpr
      else assert false

module.exports = {
  AddExpression
  SubExpression
  MulExpression
  DivExpression
  NumberExpression
  VariableExpression
  ExpressionTreeBuilder
}