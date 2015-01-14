###
Rules AST Builder
===========
Builds a Abstract Syntax Tree (AST) from a rule condition token sequence.
###

 
assert = require 'cassert'
util = require 'util'
Promise = require 'bluebird'
_ = require 'lodash'
S = require 'string'

class BoolExpression

class AndExpression extends BoolExpression
  constructor: (@left, @right) ->
    @type = "and"

  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val) => 
      if val then @right.evaluate(cache) else false 
    )
  toString: -> "and(#{@left.toString()}, #{@right.toString()})"

class OrExpression extends BoolExpression
  constructor: (@left, @right) -> #nop
    @type = "or"

  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val) => 
      if val then true else @right.evaluate(cache) 
    )
  toString: -> "or(#{@left.toString()}, #{@right.toString()})"
  
class PredicateExpression extends BoolExpression
  constructor: (@predicate) -> #nop
    @type = "predicate"
  
  evaluate: (cache) -> 
    id = @predicate.id
    value = cache[id]
    return (
      if value? then Promise.resolve(value)
      # If the trigger keyword was present then the predicate is only true of it got tiggered...
      else if @predicate.justTrigger is yes then Promise.resolve(false)
      else @predicate.handler.getValue().then( (value) =>
        cache[id] = value
        return value
      )
    )
  toString: -> "predicate('#{@predicate.token}')"

class BoolExpressionTreeBuilder
  _nextToken: ->
    if @pos < @tokens.length
      @token = @tokens[@pos++]
    else
      @token = ''
  build: (@tokens, @predicates) ->
    @pos = 0
    @_nextToken()
    return @_buildExpression()
  _buildExpression: (left = null, greedy = yes) ->
    switch @token
      when 'predicate'
        @_nextToken()
        predicateExpr = @_buildPredicateExpression()
        return (
          if greedy then @_buildExpression(predicateExpr, greedy)
          else predicateExpr
        )
      when 'or'
        @_nextToken()
        return new OrExpression(left, @_buildExpression(null, yes))
      when 'and'
        @_nextToken()
        right = @_buildExpression(null, false)
        return @_buildExpression(new AndExpression(left, right), yes)
      when '['
        @_nextToken()
        innerExpr = @_buildExpression(null, yes)
        assert @token is ']'
        @_nextToken()
        return (
          if greedy then @_buildExpression(innerExpr, greedy)
          else innerExpr
        )
      when ']', ''
        return left
      else
        assert false

  _buildPredicateExpression: ->
    assert @token is '('
    @_nextToken()
    predicateIndex = @token
    assert typeof predicateIndex is "number"
    @_nextToken()
    assert @token is ')'
    @_nextToken()
    predicate = @predicates[predicateIndex]
    return new PredicateExpression(predicate)

module.exports = {
  BoolExpression
  AndExpression
  OrExpression
  BoolExpressionTreeBuilder
}