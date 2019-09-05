###
variables AST Builder
===========
Builds a Abstract Syntax Tree (AST) from a variable expression token sequence.
###

 
cassert = require 'cassert'
assert = require 'assert'
util = require 'util'
Promise = require 'bluebird'
_ = require 'lodash'
S = require 'string'

class Expression

class AddExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache, yes).then( (val1) => 
      @right.evaluate(cache, yes).then( (val2) => parseFloat(val1) + parseFloat(val2) )
    )
  toString: -> "add(#{@left.toString()}, #{@right.toString()})"
  getUnit: ->
    leftUnit = @left.getUnit()
    rightUnit = @right.getUnit()
    if leftUnit?
      return leftUnit
    else
      return rightUnit

class SubExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache, yes).then( (val1) => 
      @right.evaluate(cache, yes).then( (val2) => parseFloat(val1) - parseFloat(val2) )
    )
  toString: -> "sub(#{@left.toString()}, #{@right.toString()})"
  getUnit: ->
    leftUnit = @left.getUnit()
    rightUnit = @right.getUnit()
    if leftUnit? and leftUnit.length > 0
      return leftUnit
    else
      return rightUnit

class MulExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache, yes).then( (val1) => 
      @right.evaluate(cache, yes).then( (val2) => parseFloat(val1) * parseFloat(val2) )
    )
  toString: -> "mul(#{@left.toString()}, #{@right.toString()})"
  getUnit: ->
    leftUnit = @left.getUnit()
    rightUnit = @right.getUnit()
    if leftUnit? and leftUnit.length > 0
      if rightUnit? and rightUnit.length > 0
        return "#{leftUnit}*#{rightUnit}"
      else
        return leftUnit
    else
      return rightUnit

class DivExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache, yes).then( (val1) => 
      @right.evaluate(cache, yes).then( (val2) => parseFloat(val1) / parseFloat(val2) )
    )
  toString: -> "div(#{@left.toString()}, #{@right.toString()})"
  getUnit: ->
    leftUnit = @left.getUnit()
    rightUnit = @right.getUnit()
    if leftUnit? and leftUnit.length > 0
      if rightUnit? and rightUnit.length > 0
        return "#{leftUnit}/#{rightUnit}"
      else
        return leftUnit
    else
      if rightUnit? and rightUnit.length > 0
        return "1/#{rightUnit}"
      else
        return null

class NumberExpression extends Expression
  constructor: (@value) -> #nop
  evaluate: (cache) -> Promise.resolve @value
  toString: -> "num(#{@value})"
  getUnit: -> null

class VariableExpression extends Expression
  constructor: (@variable) -> #nop
  evaluate: (cache, expectNumeric) ->
    name = @variable.name
    val = cache[name]
    return Promise.resolve().then( =>
      if cache[name]?
        if cache[name].value? then return cache[name].value
        else throw new Error("Dependency cycle detected for variable #{name}")
      else
        cache[name] = {}
        return @variable.getUpdatedValue(cache).then( (value) =>
          cache[name].value = value
          return value
        )
    ).then( (val) =>
      if expectNumeric
        if val isnt null
          numVal = parseFloat(val)
        else
          numVal = 0
        if isNaN(numVal) 
          throw new Error("Expected variable #{@variable.name} to have a numeric value.")
        return numVal
      else return val
    )
  getUnit: -> @variable.unit

  toString: -> "var(#{@variable.name})"

class FunctionCallExpression extends Expression
  constructor: (@name, @func, @args) -> #nop
  evaluate: (cache) ->
    context = {
      units: _.map(@args, (a) -> a.getUnit() )
    }
    return Promise
      .map(@args, ( (a) -> a.evaluate(cache) ), {concurrency: 1})
      .then( (args) => @func.exec.apply(context, args) )
  toString: -> 
    argsStr = (
      if @args.length > 0 then _.reduce(@args, (l,r) -> "#{l.toString()}, #{r.toString()}" )
      else ""
    )
    return "fun(#{@name}, [#{argsStr}])"
  getUnit: ->
    if @func.unit? 
      return @func.unit()
    return ''

class StringExpression extends Expression
  constructor: (@value) -> #nop
  evaluate: -> Promise.resolve @value
  toString: -> "str('#{@value}')"
  getUnit: -> null

class StringConcatExpression extends Expression
  constructor: (@left, @right) -> #nop
  evaluate: (cache) -> 
    return @left.evaluate(cache).then( (val1) => 
      @right.evaluate(cache).then( (val2) => "#{val1}#{val2}" )
    )
  toString: -> "con(#{@left.toString()}, #{@right.toString()})"
  getUnit: -> null

class ExpressionTreeBuilder
  constructor: (@variables, @functions) -> 
    assert @variables? and typeof @variables is "object"
    assert @functions? and typeof @functions is "object"

  _nextToken: ->
    if @pos < @tokens.length
      @token = @tokens[@pos++]
    else
      @token = ''
  build: (@tokens) ->
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
      when ')', '', ','
        return left
      else assert false, "unexpected token: '#{@token}'"

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
      when '+', '-', ')', '', ','
        return left
      else 
        right = @_buildFactor()
        return @_buildTermPrime(new StringConcatExpression(left, right))

  _buildFactor: () ->
    switch 
      when @token is '('
        @_nextToken()
        expr = @_buildExpression()
        cassert @token is ')'
        @_nextToken()
        return expr
      when @_isNumberToken()
        numberExpr = new NumberExpression(@token)
        @_nextToken()
        return numberExpr
      when @_isVariableToken()
        varName = @token.substr(1)
        variable = @variables[varName]
        unless variable? then throw new Error("Could not find variable #{@token}")
        varExpr = new VariableExpression(variable)
        @_nextToken()
        return varExpr
      when @_isStringToken()
        str = @token[1...@token.length-1]
        strExpr = new StringExpression(str)
        @_nextToken()
        return strExpr
      when @token.match(/[_a-zA-Z][_a-zA-Z0-9]*/)?
        funcName = @token
        func = @functions[funcName]
        unless func? then throw new Error("Could not find function #{funcName}")
        @_nextToken()
        cassert @token is '('
        @_nextToken()
        args = []
        while @token isnt ')'
          args.push @_buildExpression()
          cassert @token in [')', ',']
          @_nextToken() if @token is ','
        cassert @token is ')'
        @_nextToken()
        funcCallExpr = new FunctionCallExpression(funcName, func, args)
        return funcCallExpr
      else assert false, "unexpected token: '#{@token}'"

  _isStringToken: -> (@token.length > 0 and @token[0] is '"')
  _isVariableToken: -> (@token.length > 0 and @token[0] is '$')
  _isNumberToken: -> (typeof @token is "number")


module.exports = {
  AddExpression
  SubExpression
  MulExpression
  DivExpression
  NumberExpression
  VariableExpression
  ExpressionTreeBuilder
}