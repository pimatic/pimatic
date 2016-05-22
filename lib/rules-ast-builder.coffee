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
  toString: -> "#{@type.replace(' ', '')}(#{@left.toString()}, #{@right.toString()})"

class AndExpression extends BoolExpression
  constructor: (@type, @left, @right) ->

  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val) => 
      if val then @right.evaluate(cache) else false 
    )

class OrExpression extends BoolExpression
  constructor: (@type, @left, @right) -> #nop

  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val) => 
      if val then true else @right.evaluate(cache) 
    )
  
class PredicateExpression extends BoolExpression
  constructor: (@predicate) -> #nop
    @type = "predicate"
  
  evaluate: (cache) ->
    id = @predicate.id
    value = cache[id]
    return (
      if value? then Promise.resolve(value)
      # If the trigger keyword was present then the predicate is only true of it got triggered...
      else if @predicate.justTrigger is yes then Promise.resolve(false)
      else @predicate.handler.getValue().then( (value) =>
        # Check if the time condition is true
        if @predicate.for? and value is true
          return @predicate.timeAchived
        else
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

  _buildOuterExpression: (left, inner) ->
    if not inner
      return @_buildExpression(left, yes, no)
    else
      return left

  _buildExpression: (left = null, greedy = yes, inner = false) ->
    switch @token
      when 'predicate'
        @_nextToken()
        predicateExpr = @_buildPredicateExpression()
        return (
          if greedy then @_buildExpression(predicateExpr, greedy, inner)
          else predicateExpr
        )
      when 'or'
        @_nextToken()
        outer = new OrExpression('or', left, @_buildExpression(null, yes, yes))
        return @_buildOuterExpression(outer, inner)
      when 'or when'
        if inner then return left
        @_nextToken()
        outer = new OrExpression('or when', left, @_buildExpression(null, yes, yes))
        return @_buildOuterExpression(outer, inner)
      when 'and'
        @_nextToken()
        right = @_buildExpression(null, false)
        return @_buildExpression(new AndExpression('and', left, right), yes)
      when 'and if'
        @_nextToken()
        outer = new AndExpression('and if', left, @_buildExpression(null, yes, yes))
        return @_buildOuterExpression(outer, inner)
      when '['
        @_nextToken()
        innerExpr = @_buildExpression(null, yes, yes)
        assert @token is ']'
        @_nextToken()
        return (
          if greedy then @_buildExpression(innerExpr, greedy, false, yes)
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
