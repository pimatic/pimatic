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
        assert variable.value? and variable.name.length > 0
        variable.name = variable.name.substring(1) if variable.name[0] is '$'
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
              @emit "change #{varName}", value
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
      @emit 'change', name, value
      @emit "change #{name}", value
      return

    isVariableDefined: (name) ->
      assert name? and typeof name is "string"
      return @variables[name]?

    getVariableValue: (name) ->
      assert name? and typeof name is "string"
      if @variables[name]?
        return @variables[name].getValue()
      else
        return null

    isAVariable: (token) -> token.length > 0 and token[0] is '$'

    extractVariables: (tokens) ->
      return (vars = t.substring(1) for t in tokens when @isAVariable(t))

    evaluateNumericExpression: (tokens) ->
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
              awaiting.push @getVariableValue(varName).then( (value) ->
                if isNaN(value)
                  throw new Error("Expected #{t} to have a numeric value (was: #{value}).")
                tokens[i] = parseFloat(value)
              )
        return Q.all(awaiting).then( => bet.evaluateSync(tokens) )
      )

  return exports = { VariableManager }