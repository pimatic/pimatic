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
        assert(typeof variable.value is 'number' or variable.value.length > 0) if variable.value?
        variable.name = variable.name.substring(1) if variable.name[0] is '$'
        if variable.expression?
          expr = variable.expression.trim()
          try
            if expr.length is 0
              throw new Error("No expression given")
            tokens = null
            m = M(expr).matchAnyExpression((m, ts) => tokens = ts)
            unless m.hadMatch() and m.getFullMatch() is expr
              throw new Error("no match")
            @setVariableToExpr(variable.name, tokens, expr)
          catch e
            env.logger.error(
              "Error parsing and adding expression variable #{variable.name}:", e.message
            )
            env.logger.debug e
        else
          assert variable.value?
          @setVariableToValue(variable.name, variable.value)

      # For each new device add a variable for every attribute
      @framework.on 'deviceAdded', (device) =>
        for attrName, attr of device.attributes
          do (attrName, attr) =>
            varName = "#{device.id}.#{attrName}"
            lastValue = null
            device.on(attrName, attrListener = (value) =>
              lastValue = value
              eventObj = {name: varName, value, type: 'attribute'}
              @emit('change', eventObj)
              @emit("change #{varName}", eventObj)
            )
            @variables[varName] = {
              type: 'attribute'
              readonly: yes
              getValue: => 
                if lastValue? then Q(lastValue) else device.getAttributeValue(attrName)
              destroy: => device.emitter.removeListener(attrName, attrListener)
            }

    setVariableToExpr: (name, tokens, inputStr) ->
      assert name? and typeof name is "string"
      assert tokens.length > 0
      assert typeof inputStr is "string" and inputStr.length > 0

      type = (if tokens[0][0] is '"' then "string" else "numeric")

      lastValue = null
      getValue = (
        switch type
          when "numeric" then (varsInEvaluation) => 
            if lastValue? then Q(lastValue) 
            else @evaluateNumericExpression(tokens, varsInEvaluation)
          when "string" then  (varsInEvaluation) => 
            if lastValue? then Q(lastValue)
            else @evaluateStringExpression(tokens, varsInEvaluation)
      )

      assert typeof getValue is "function"

      isNew = (not @variables[name]?)
      unless isNew
        oldVariable = @variables[name]
        unless oldVariable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an expression")
        oldVariable.destroy()

      variables = (t.substring(1) for t in tokens when @isAVariable(t)) 
      @on('change', changeListener = (vName, value) =>
        if vName in variables
          getValue().then( (value) => 
            if lastValue is value then return 
            lastValue = value
            eventObj = {name, value, type: "expression", exprInputStr: inputStr, exprTokens: tokens}
            @emit('change', eventObj)
            @emit("change #{name}", eventObj)
          ).catch((error) =>
            env.logger.error("Error updating expression value:", error.message)
            env.logger.debug error
          )
      )
      @variables[name] = {
        type: "expression"
        exprInputStr: inputStr 
        exprTokens: tokens
        readonly: no
        getValue: getValue
        destroy: => @removeListener('change', changeListener)
      }

      getValue().then( (value) =>
        lastValue = value
        eventObj = {name, value, type: "expression", exprInputStr: inputStr, exprTokens: tokens}
        @emit('add', eventObj) if isNew
        @emit('change', eventObj)
        @emit("change #{name}", eventObj)
      ).catch((error) =>
        env.logger.error("Error getting value for expression:", error.message)
        env.logger.debug error
      )

    _checkVariableName: (name) ->
      unless name.match /^[a-z0-9\-_]+$/i
        throw new Error(
          "variable name must only contain alpha numerical symbols, \"-\" and  \"_\""
        )

    setVariableToValue: (name, value) ->
      assert name? and typeof name is "string"
      @_checkVariableName(name)

      isNew = (not @variables[name]?)
      unless isNew
        oldVariable = @variables[name]
        if oldVariable.readonly
          throw new Error("Can not set $#{name}, the variable in readonly.")
        unless oldVariable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an value")
        oldVariable.destroy()
      
      @variables[name] = { 
        type: "value"
        readonly: no
        getValue: => Q(value)
        destroy: => #nop
      } 
      eventObj = {name, value, type: 'value'}
      @emit('add', eventObj) if isNew
      @emit('change', eventObj)
      @emit("change #{name}", eventObj)
      return

    updateVariable: (name, type, valueOrExpr) ->
      assert type in ["value", "expression"]

      unless @isVariableDefined(name)
        throw new Error("No variable with the name \"#{variableName}\" found.")

      return (
        switch type
          when "value" then @setVariableToValue(name, valueOrExpr)
          when "expression"
            tokens = null
            m = M(valueOrExpr).matchAnyExpression((m, ts) => tokens = ts)
            unless m.hadMatch() and m.getFullMatch() is valueOrExpr
              throw new Error("Could not parse expression")
            @setVariableToExpr(name, tokens, variableExpression)
      )

    addVariable: (name, type, valueOrExpr) ->
      if @isVariableDefined(name)
        throw new Error("There is already a variable with the name \"#{variableName}\"")
      return @updateVariable(name, type, valueOrExpr)

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
        if @variables[name].type is 'attribute'
          throw new Error("Can not delete a variable for a device attribute.")
        @variables[name].destroy()
        delete @variables[name]
        @emit "remove", name

    getAllVariables: () ->
      return (for name, v of @variables
        varInfo = {name, readonly: v.readonly, type: v.type, value:@getVariableValue(name) }
        if v.type is "expression"
          varInfo.exprInputStr = v.exprInputStr 
          varInfo.exprTokens = v.exprTokens
        varInfo
      )

    getVariableByName: (name) ->
      v = @variables[name]
      unless v? then return null
      varInfo = {name: name, readonly: v.readonly, type: v.type}
      if v.type is "expression"
        varInfo.exprInputStr = v.exprInputStr 
        varInfo.exprTokens = v.exprTokens
      return varInfo

    isAVariable: (token) -> token.length > 0 and token[0] is '$'

    extractVariables: (tokens) ->
      return (vars = t.substring(1) for t in tokens when @isAVariable(t))

    evaluateNumericExpression: (tokens, varsInEvaluation = {}) ->
      return Q.fcall( =>
        tokens = _.clone(tokens)
        awaiting = []
        for t, i in tokens
          do (i, t) =>
            unless isNaN(parseFloat(t))
              tokens[i] = parseFloat(t)
            else if @isAVariable(t)
              varName = t.substring(1)
              # Replace variable by its value
              unless @isVariableDefined(varName)
                throw new Error("#{t} is not defined")
              awaiting.push @getVariableValue(varName, _.clone(varsInEvaluation)).then( (value) ->
                if isNaN(parseFloat(value))
                  throw new Error("Expected #{t} to have a numeric value (was: #{value}).")
                tokens[i] = parseFloat(value)
              )
        return Q.all(awaiting).then( => bet.evaluateSync(tokens) )
      )

    evaluateStringExpression: (tokens, varsInEvaluation = {}) ->
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
              awaiting.push @getVariableValue(varName, _.clone(varsInEvaluation)).then( (value) ->
                tokens[i] = value
              )
            else 
              assert t.length >= 2
              assert t[0] is '"' and t[t.length-1] is '"' 
              tokens[i] = t[1...t.length-1]
        return Q.all(awaiting).then( => _(tokens).reduce( (l, r) => "#{l}#{r}") )
      )


  return exports = { VariableManager }