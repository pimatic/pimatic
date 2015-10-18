###
Variable Manager
===========
###

assert = require 'cassert'
util = require 'util'
Promise = require 'bluebird'
_ = require 'lodash'
S = require 'string'
M = require './matcher'
humanFormat = require 'human-format'
isNumber = (n) -> "#{n}".match(/^-?[0-9]+\.?[0-9]*$/)?
varsAst = require './variables-ast-builder'

module.exports = (env) ->

  class Variable
    name: null
    value: null
    type: 'value'
    readonly: no
    unit: null

    constructor: (@_vars, @name, @type, @unit, @readonly) ->
      assert @_vars?
      assert @_vars instanceof VariableManager
      assert typeof @name is "string"
      assert typeof @type is "string"
      assert typeof @readonly is "boolean"

    getCurrentValue: -> @value
    _setValue: (value) ->
      if isNumber value
        numValue = parseFloat(value)
        value = numValue unless isNaN(numValue)
      @value = value
      @_vars._emitVariableValueChanged(this, @value)
      return true
    toJson: -> {
      name: @name
      readonly: @readonly
      type: @type
      value: @value
      unit: @unit or ''
    }

  class DeviceAttributeVariable extends Variable
    constructor: (vars, @_device, @_attrName) ->
      super(
        vars, 
        "#{@_device.id}.#{_attrName}", 
        'attribute', 
        @_device.attributes[@_attrName].unit, 
        yes
      )
      @_addListener()

    _addListener: () ->
      @_device.on(@_attrName, @_attrListener = (value) => @_setValue(value) )
      @_device.on('change', @_deviceChangeListener = (newDevice) =>
        if newDevice.hasAttribute(@_attrName)
          @unit = newDevice.attributes[@_attrName].unit
          @_removeListener()
          @_device = newDevice
          @_addListener()
        else
          @_vars._removeDeviceAttributeVariable(@name)
      )
      @_device.on('destroy', @_deviceDestroyListener = =>
        @_vars._removeDeviceAttributeVariable(@name)
      )

    _removeListener: () ->
      @_device.removeListener(@_attrName, @_attrListener)
      @_device.removeListener("change", @_deviceChangeListener)
      @_device.removeListener("destroy", @_deviceDestroyListener)
      
    getUpdatedValue: (varsInEvaluation = {}) -> 
      return @_device.getUpdatedAttributeValue(@_attrName, varsInEvaluation)

    destroy: =>
      @_removeListener()
      return


  class ExpressionValueVariable extends Variable
    constructor: (vars, name, type, unit, valueOrExpr = null) ->
      super(vars, name, type, unit, no)
      assert type in ['value', 'expression']
      if valueOrExpr?
        switch type
          when 'value' then @setToValue(valueOrExpr, unit)
          when 'expression' then @setToExpression(valueOrExpr, unit)
          else assert false

    setToValue: (value, unit) ->
      @_removeListener()
      @type = "value"
      @_datatype = null
      @exprInputStr = null
      @exprTokens = null
      @unit = unit
      return @_setValue(value)

    setToExpression: (expression, unit) ->
      {tokens, datatype} = @_vars.parseVariableExpression(expression)
      @exprInputStr = expression
      @exprTokens = tokens
      @_datatype = datatype
      @_removeListener()
      @type = "expression"
      @unit = unit
      variablesInExpr = (t.substring(1) for t in tokens when @_vars.isAVariable(t))
      doUpdate = ( =>
        @getUpdatedValue().then( (value) => 
          @_setValue(value)
        ).catch( (error) =>
          env.logger.error("Error updating expression value:", error.message)
          env.logger.debug error
          return error
        )
      )
      @_vars.on('variableValueChanged', @_changeListener = (changedVar, value) =>
        unless changedVar.name in variablesInExpr then return
        doUpdate()
      )
      return doUpdate()

    _removeListener: ->
      if @_changeListener?
        @_vars.removeListener('variableValueChanged', @_changeListener)
        @changeListener = null

    getUpdatedValue: (varsInEvaluation = {})->
      if @type is "value" then return Promise.resolve(@value)
      else 
        assert @exprTokens?
        return @_vars.evaluateExpression(@exprTokens, varsInEvaluation)

    toJson: ->
      jsonObject = super()
      if @type is "expression"
        jsonObject.exprInputStr = @exprInputStr
        jsonObject.exprTokens = @exprTokens
      return jsonObject
    
    destroy: ->
      @_removeListener()


  ###
  The Variable Manager
  ----------------
  ###
  class VariableManager extends require('events').EventEmitter

    variables: {}
    functions: {
      min:
        args:
          numbers:
            type: "number"
            multiple: yes
        exec: (args...) -> _.reduce(_.map(args, parseFloat), (a, b) -> Math.min(a,b) )
      max:
        args:
          numbers:
            type: "number"
            multiple: yes
        exec: (args...) -> _.reduce(_.map(args, parseFloat), (a, b) -> Math.max(a,b) )
      avg:
        args:
          numbers:
            type: "number"
            multiple: yes
        exec: (args...) ->  _.reduce(_.map(args, parseFloat), (a, b) -> a+b) / args.length    
      random:
        args:
          min:
            type: "number"
          max:
            type: "number"
        exec: (min, max) -> 
          minf = parseFloat(min)
          maxf = parseFloat(max)
          return Math.floor( Math.random() * (maxf+1-minf) ) + minf
      round:
        args:
          number:
            type: "number"
          decimals:
            type: "number"
            optional: yes
        exec: (value, decimals) -> 
          unless decimals?
            decimals = 0
          multiplier = Math.pow(10, decimals)
          return Math.round(value * multiplier) / multiplier
      roundToNearest:
        args:
          number:
            type: "number"
          steps:
            type: "number"
        exec: (number, steps) ->
          steps = String(steps)
          decimals = (if steps % 1 != 0 then steps.substr(steps.indexOf(".") + 1).length else 0)
          return Number((Math.round(number / steps) * steps).toFixed(decimals))
      timeFormat:
        args:
          number:
            type: "number"
        exec: (number) ->
          hours = parseInt(number)
          decimalMinutes = (number-hours) * 60
          minutes = Math.floor(decimalMinutes)
          seconds = Math.round((decimalMinutes % 1) * 60)
          if seconds == 60
            minutes += 1
            seconds = "0"
          if minutes == 60
            hours += 1
            minutes = "0"
          hours = "0" + hours if hours < 10
          minutes = "0" + minutes if minutes < 10
          seconds = "0" + seconds if seconds < 10
          return "#{hours}:#{minutes}:#{seconds}"
      timeDecimal:
        args:
          time:
            type: "string"
        exec: (time) ->
          hours = time.substr(0, time.indexOf(':'))
          minutes = time.substr(hours.length + 1, 2)
          seconds = time.substr(hours.length + minutes.length + 2, 2)

          return parseInt(hours) + parseFloat(minutes / 60) + parseFloat(seconds / 3600)
      date:
        args:
          format:
            type: "string"
            optional: yes
        exec: (format) -> (new Date()).format(if format? then format else 'YYYY-MM-DD hh:mm:ss')
      formatNumber:
        args:
          number:
            type: "number"
          decimals:
            type: "number"
            optional: yes
          unit:
            type: "string"
            optional: yes
        exec: (number, decimals, unit) ->
          unless unit?
            info = humanFormat.raw(number, unit: this.units[0] )
            formated = (if decimals? then Number(info.num) else info.num)
            return "#{formated}#{info.prefix}#{info.unit}"
          else
            unless decimals?
              decimals = 2
            formated = Number(number).toFixed(decimals)
            return "#{formated}#{unit}"
    }

    constructor: (@framework, @variablesConfig) ->
      # For each new device add a variable for every attribute
      @framework.on 'deviceAdded', (device) =>
        for attrName, attr of device.attributes
          @_addVariable(
            new DeviceAttributeVariable(this, device, attrName)
          )

    init: () ->
      # Import variables
      setExpressions = []

      for variable in @variablesConfig
        do (variable) =>
          assert variable.name? and variable.name.length > 0
          variable.name = variable.name.substring(1) if variable.name[0] is '$'
          if variable.expression?
            try
              exprVar = new ExpressionValueVariable(
                this, 
                variable.name,
                'expression',
                variable.unit
              )
              # We first add the variable, but parse the expression later, because it could
              # contain other variables, added later
              @_addVariable(exprVar)
              setExpressions.push( -> 
                try
                  exprVar.setToExpression(variable.expression.trim()) 
                catch
                  env.logger.error(
                    "Error parsing expression variable #{variable.name}:", e.message
                  )
                  env.logger.debug e
              )
            catch e
              env.logger.error(
                "Error adding expression variable #{variable.name}:", e.message
              )
              env.logger.debug e.stack
          else
            @_addVariable(
              new ExpressionValueVariable(
                this, 
                variable.name, 
                'value',
                variable.unit,
                variable.value
              )
            )

      setExpr() for setExpr in setExpressions
          
    _addVariable: (variable) ->
      assert variable instanceof Variable
      assert (not @variables[variable.name]?)
      @variables[variable.name] = variable
      Promise.resolve().then( ->
        variable.getUpdatedValue().then( (value) -> variable._setValue(value) )
      ).catch( (error) ->
        env.logger.warn("Could not update variable #{variable.name}: #{error.message}")
        env.logger.debug(error)
      )
      @_emitVariableAdded(variable)
      return

    _emitVariableValueChanged: (variable, value) ->
      @emit('variableValueChanged', variable, value)

    _emitVariableAdded: (variable) ->
      @emit('variableAdded', variable)

    _emitVariableChanged: (variable) ->
      @emit('variableChanged', variable)

    _emitVariableRemoved: (variable) ->
      @emit('variableRemoved', variable)

    getVariablesAndFunctions: (ops) -> 
      unless ops?
        return {variables: @variables, functions: @functions}
      else
        filteredVars = _.filter(@variables, ops)
        variables = {}
        for v in filteredVars
          variables[v.name] = v
        return {
          variables,
          functions: @functions
        }
     

    parseVariableExpression: (expression) ->
      tokens = null
      context = M.createParseContext(@variables, @functions)
      m = M(expression, context).matchAnyExpression( (m, ts) => tokens = ts)
      unless m.hadMatch() and m.getFullMatch() is expression
        throw new Error("Could not parse expression")
      datatype = (if tokens[0][0] is '"' then "string" else "numeric")
      return {tokens, datatype}


    setVariableToExpr: (name, inputStr, unit) ->
      assert name? and typeof name is "string"
      assert typeof inputStr is "string" and inputStr.length > 0

      unless @variables[name]?
        @_addVariable(
          variable = new ExpressionValueVariable(this, name, 'expression', unit, inputStr)
        )
      else
        variable = @variables[name]
        unless variable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an expression")
        variable.setToExpression(inputStr, unit)
        @_emitVariableChanged(variable)
      return variable
    


    _checkVariableName: (name) ->
      unless name.match /^[a-z0-9\-_]+$/i
        throw new Error(
          "Variable name must only contain alpha numerical symbols, \"-\" and  \"_\""
        )

    setVariableToValue: (name, value, unit) ->
      assert name? and typeof name is "string"
      @_checkVariableName(name)

      unless @variables[name]?
        @_addVariable(
          variable = new ExpressionValueVariable(this, name, 'value', unit, value)
        )
      else
        variable = @variables[name]
        unless variable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an expression")
        if variable.type is "expression"
          variable.setToValue(value, unit)
          @_emitVariableChanged(variable)
        else if variable.type is "value"
          variable.setToValue(value, unit)
      return variable


    updateVariable: (name, type, valueOrExpr, unit) ->
      assert type in ["value", "expression"]
      unless @isVariableDefined(name)
        throw new Error("No variable with the name \"#{name}\" found.")
      return (
        switch type
          when "value" then @setVariableToValue(name, valueOrExpr, unit)
          when "expression" then @setVariableToExpr(name, valueOrExpr, unit)
      )

    addVariable: (name, type, valueOrExpr, unit) ->
      assert type in ["value", "expression"]
      if @isVariableDefined(name)
        throw new Error("There is already a variable with the name \"#{name}\"")
      return (
        switch type
          when "value" then @setVariableToValue(name, valueOrExpr, unit)
          when "expression" then @setVariableToExpr(name, valueOrExpr, unit)
      )

    isVariableDefined: (name) ->
      assert name? and typeof name is "string"
      return @variables[name]?

    getVariableValue: (name) -> @variables[name]?.value

    getVariableUpdatedValue: (name, varsInEvaluation = {}) ->
      assert name? and typeof name is "string"
      if @variables[name]?
        if varsInEvaluation[name]?
          if varsInEvaluation[name].value?
            return Promise.resolve(varsInEvaluation[name].value)
          else 
            return Promise.try => throw new Error("Dependency cycle detected for variable #{name}")
        else
          varsInEvaluation[name] = {}
          return @variables[name].getUpdatedValue(varsInEvaluation).then( (value) =>
            varsInEvaluation[name].value = value
            return value
          )
      else
        return null

    removeVariable: (name) ->
      assert name? and typeof name is "string"
      variable = @variables[name]
      if variable?
        if variable.type is 'attribute'
          throw new Error("Can not delete a variable for a device attribute.")
        variable.destroy()
        delete @variables[name]
        @_emitVariableRemoved(variable)

    _removeDeviceAttributeVariable: (name) ->
      assert name? and typeof name is "string"
      variable = @variables[name]
      if variable?
        if variable.type isnt 'attribute'
          throw new Error("Not a device attribute.")
        variable.destroy()
        delete @variables[name]
        @_emitVariableRemoved(variable)

    getVariables: () ->
      variables = (v for name, v of @variables)
      # sort in config order
      variablesInConfig = _.map(@framework.config.variables, (r) => r.name )
      return _.sortBy(variables, (r) => variablesInConfig.indexOf r.name )

    getFunctions: () -> @functions

    getVariableByName: (name) ->
      v = @variables[name]
      unless v? then return null
      return v

    isAVariable: (token) -> token.length > 0 and token[0] is '$'

    extractVariables: (tokens) ->
      return (vars = t.substring(1) for t in tokens when @isAVariable(t))

    notifyOnChange: (tokens, listener) ->
      variablesInExpr = @extractVariables(tokens)
      @on('variableValueChanged', changeListener = (changedVar, value) =>
        unless changedVar.name in variablesInExpr then return
        listener(changedVar)
      )
      listener.__variableChangeListener = changeListener

    cancelNotifyOnChange: (listener) ->
      assert typeof listener.__variableChangeListener is "function"
      @removeListener('variableValueChanged', listener.__variableChangeListener)

    evaluateExpression: (tokens, varsInEvaluation = {}) ->
      builder = new varsAst.ExpressionTreeBuilder(@variables, @functions)
      # do building async
      return Promise.resolve().then( =>
        expr = builder.build(tokens)
        return expr.evaluate(varsInEvaluation)
      )

    evaluateExpressionWithUnits: (tokens, varsInEvaluation = {}) ->
      builder = new varsAst.ExpressionTreeBuilder(@variables, @functions)
      # do building async
      return Promise.resolve().then( =>
        expr = builder.build(tokens)
        return expr.evaluate(varsInEvaluation).then( (value) =>
          return { value: value, unit: expr.getUnit() }
        )
      )

    inferUnitOfExpression: (tokens) ->
      builder = new varsAst.ExpressionTreeBuilder(@variables, @functions)
      expr = builder.build(tokens)
      return expr.getUnit()

    evaluateNumericExpression: (tokens, varsInEvaluation = {}) ->
      return @evaluateExpression(tokens, varsInEvaluation)

    evaluateStringExpression: (tokens, varsInEvaluation = {}) ->
      return @evaluateExpression(tokens, varsInEvaluation)

    updateVariableOrder: (variableOrder) ->
      assert variableOrder? and Array.isArray variableOrder
      @framework.config.variables = @variablesConfig = _.sortBy(
        @variablesConfig,  
        (variable) => 
          index = variableOrder.indexOf variable.name
          return if index is -1 then 99999 else index # push it to the end if not found
      )
      @framework.saveConfig()
      @framework._emitVariableOrderChanged(variableOrder)
      return variableOrder



  return exports = { VariableManager }
