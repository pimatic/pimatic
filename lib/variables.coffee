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

module.exports = (env) ->

  ###
  The Variable Manager
  ----------------
  ###
  class VariableManager extends require('events').EventEmitter

    variables: {}

    constructor: (@framework) ->
      @framework.on 'device', (device) =>
        for attrName, attr of device.attributes
          do (attrName, attr) =>
            varName = "#{device.id}.#{attrName}"
            @variables[varName] = {
              readonly: yes
              getValue: => device.getAttributeValue(attrName)
            }

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
      @emit 'change #{name}', value
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


  return exports = { VariableManager }