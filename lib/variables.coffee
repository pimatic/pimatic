###
Variable Manager
===========
###

assert = require 'cassert'
util = require 'util'
Q = require 'q'
_ = require 'lodash'
S = require 'string'
M = require './matcher'
bet = require 'bet'

module.exports = (env) ->

  ###
  The Variable Manager
  ----------------
  ###
  class VariableManager extends require('events').EventEmitter

    variables: {}

    constructor: (@framework, variables) ->
      # Import variables
      for variable in variables
        assert variable.name? and variable.name.length > 0
        assert(variable.value.length > 0) if variable.value?
        variable.name = variable.name.substring(1) if variable.name[0] is '$'
        if variable.expression?
          expr = variable.expression
          assert expr.length > 0
          @setVariableExpr(variable.name, exp)
        else
          assert variable.value?
          @setVariable(variable.name, variable.value)

      # For each new device add a variable for every attribute
      @framework.on 'device', (device) =>
        for attrName, attr of device.attributes
          do (attrName, attr) =>
            varName = "#{device.id}.#{attrName}"
            @variables[varName] = {
              readonly: yes
              getValue: => device.getAttributeValue(attrName)
            }
            device.on(attrName, (value) =>
              @emit 'change', varName, value
              @emit "change #{varName}", value
            )


    setVariableExpr: (name, tokens) ->
      assert name? and typeof name is "string"
      assert tokens.length > 0
      type = (if tokens[0][0] is '"' then "string" else "numeric")

      getValue = (
        switch type
          when "numeric" then (varsInEvaluation) => 
            @evaluateNumericExpression(tokens, varsInEvaluation)
          when "string" then  (varsInEvaluation) => 
            @evaluateStringExpression(tokens, varsInEvaluation)
      )

      assert typeof getValue is "function"

      isNew = (@variables[name]?)

      # TODO: Add change listener on dependent variables
      @variables[name] = {
        expression: tokens
        readonly: yes
        getValue: getValue
      }

      @variables[name].getValue( (value) =>
        @emit('add', name, value) if isNew
        @emit 'change', name, value
        @emit "change #{name}", value
      )

    setVariable: (name, value) ->
      assert name? and typeof name is "string"
      if @variables[name]?
        if @variables[name].readonly
          throw new Error("Can not set $#{name}, the variable in readonly.")
        oldValue = @variables[name].value
        if oldValue is value
          return
        @variables[name].getValue = => Q(value)
      else
        @variables[name] = { 
          readonly: no
          getValue: => Q(value) 
        }
        @emit 'add', name, value
      @emit 'change', name, value
      @emit "change #{name}", value
      return

    isVariableDefined: (name) ->
      assert name? and typeof name is "string"
      return @variables[name]?

    getVariableValue: (name, varsInEvaluation = {}) ->
      assert name? and typeof name is "string"
      if @variables[name]?
        if varsInEvaluation[name]?
          if varsInEvaluation[name].value? then return Q(varsInEvaluation[name].value)
          else return Q.fcall => throw new Error("Dependency cycle detected for variable #{name}")
        else
          varsInEvaluation[name] = {}
          return @variables[name].getValue(varsInEvaluation).then( (value) =>
            varsInEvaluation[name].value = value
            return value
          )
      else
        return null

    removeVariable: (name) ->
      assert name? and typeof name is "string"
      if @variables[name]?
        delete @variables[name]
        @emit "remove", name

    getAllVariables: () ->
      return ({name, readonly: v.readonly} for name, v of @variables)

    isAVariable: (token) -> token.length > 0 and token[0] is '$'

    extractVariables: (tokens) ->
      return (vars = t.substring(1) for t in tokens when @isAVariable(t))

    evaluateNumericExpression: (tokens, varsInEvaluation = {}) ->
      return Q.fcall( =>
        tokens = _.clone(tokens)
        awaiting = []
        for t, i in tokens
          do (i, t) =>
            unless isNaN(t)
              tokens[i] = parseFloat(t)
            else if @isAVariable(t)
              varName = t.substring(1)
              # Replace variable by its value
              unless @isVariableDefined(varName)
                throw new Error("#{t} is not defined")
              awaiting.push @getVariableValue(varName, varsInEvaluation).then( (value) ->
                if isNaN(value)
                  throw new Error("Expected #{t} to have a numeric value (was: #{value}).")
                tokens[i] = parseFloat(value)
              )
        return Q.all(awaiting).then( => bet.evaluateSync(tokens) )
      )

    evaluateStringExpression: (tokens) ->
      return Q.fcall( =>
        tokens = _.clone(tokens)
        awaiting = []
        for t, i in tokens
          do (i, t) =>
            if @isAVariable(t)
              varName = t.substring(1)
              # Replace variable by its value
              unless @isVariableDefined(varName)
                throw new Error("#{t} is not defined")
              awaiting.push @getVariableValue(varName).then( (value) ->
                tokens[i] = value
              )
            else 
              assert t.length >= 2
              assert t[0] is '"' and t[t.length-1] is '"' 
              tokens[i] = t[1...t.length-1]
        return Q.all(awaiting).then( => _(tokens).reduce( (l, r) => "#{l}#{r}") )
      )


  return exports = { VariableManager }