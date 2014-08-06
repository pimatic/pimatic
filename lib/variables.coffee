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

varsAst = require './variables-ast-builder'

module.exports = (env) ->

  class Variable
    name: null
    value: null
    type: 'value'
    readonly: no

    constructor: (@_vars, @name, @type, @readonly) ->
      assert @_vars?
      assert @_vars instanceof VariableManager
      assert typeof @name is "string"
      assert typeof @type is "string"
      assert typeof @readonly is "boolean"

    getCurrentValue: -> @value
    _setValue: (value) ->
      numValue = parseFloat(value)
      value = numValue unless isNaN(numValue)
      if value is @value then return false
      @value = value
      @_vars._emitVariableValueChanged(this, @value)
      return true
    toJson: -> {
      name: @name
      readonly: @readonly
      type: @type
      value: @value
    }

  class DeviceAttributeVariable extends Variable
    constructor: (vars, @_device, @_attrName) ->
      super(vars, "#{@_device.id}.#{_attrName}", 'attribute', yes)
      @_device.on(@_attrName, @_attrListener = (value) => @_setValue(value) )
    getUpdatedValue: -> 
      return @_device.getUpdatedAttributeValue(@_attrName)
    destroy: => 
      @_device.removeListener(@_attrName, @_attrListener)
      return


  class ExpressionValueVariable extends Variable
    constructor: (vars, name, type, valueOrExpr = null) ->
      super(vars, name, type, no)
      assert type in ['value', 'expression']
      if valueOrExpr?
        switch type
          when 'value' then @setToValue(valueOrExpr)
          when 'expression' then @setToExpression(valueOrExpr)
          else assert false

    setToValue: (value) ->
      @_removeListener()
      @type = "value"
      @_datatype = null
      @exprInputStr = null
      @exprTokens = null
      return @_setValue(value)

    setToExpression: (expression) ->
      {tokens, datatype} = @_vars.parseVariableExpression(expression)
      @exprInputStr = expression
      @exprTokens = tokens
      @_datatype = datatype
      @_removeListener()
      @type = "expression"
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
        argc: 2
        exec: (a, b) -> Math.min(a, b)
      max:
        argc: 2
        exec: (a, b) -> Math.max(a, b)
      random:
        argc: 2
        exec: (min, max) -> Math.floor((Math.random() * max) + min)
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
          assert(typeof variable.value is 'number' or variable.value.length > 0) if variable.value?
          variable.name = variable.name.substring(1) if variable.name[0] is '$'
          if variable.expression?
            try
              exprVar = new ExpressionValueVariable(
                this, 
                variable.name, 
                'expression'
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
            assert variable.value?
            @_addVariable(
              new ExpressionValueVariable(
                this, 
                variable.name, 
                'value', 
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
      varsAndFuns = @getVariablesAndFunctions()
      context = M.createParseContext(@variables, @functions)
      m = M(expression, context).matchAnyExpression( (m, ts) => tokens = ts)
      unless m.hadMatch() and m.getFullMatch() is expression
        throw new Error("Could not parse expression")
      datatype = (if tokens[0][0] is '"' then "string" else "numeric")
      return {tokens, datatype}


    setVariableToExpr: (name, inputStr) ->
      assert name? and typeof name is "string"
      assert typeof inputStr is "string" and inputStr.length > 0

      unless @variables[name]?
        @_addVariable(
          variable = new ExpressionValueVariable(this, name, 'expression', inputStr)
        )
      else
        variable = @variables[name]
        unless variable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an expression")
        variable.setToExpression(inputStr)
        @_emitVariableChanged(variable)
      return variable
    


    _checkVariableName: (name) ->
      unless name.match /^[a-z0-9\-_]+$/i
        throw new Error(
          "variable name must only contain alpha numerical symbols, \"-\" and  \"_\""
        )

    setVariableToValue: (name, value) ->
      assert name? and typeof name is "string"
      @_checkVariableName(name)

      unless @variables[name]?
        @_addVariable(
          variable = new ExpressionValueVariable(this, name, 'value', value)
        )
      else
        variable = @variables[name]
        unless variable.type in ["expression", "value"]
          throw new Error("Can not set a non expression or value var to an expression")
        if variable.type is "expression"
          variable.setToValue(value)
          @_emitVariableChanged(variable)
        else if variable.type is "value"
          variable.setToValue(value)
      return variable


    updateVariable: (name, type, valueOrExpr) ->
      assert type in ["value", "expression"]
      unless @isVariableDefined(name)
        throw new Error("No variable with the name \"#{name}\" found.")
      return (
        switch type
          when "value" then @setVariableToValue(name, valueOrExpr)
          when "expression" then @setVariableToExpr(name, valueOrExpr)
      )

    addVariable: (name, type, valueOrExpr) ->
      assert type in ["value", "expression"]
      if @isVariableDefined(name)
        throw new Error("There is already a variable with the name \"#{name}\"")
      return (
        switch type
          when "value" then @setVariableToValue(name, valueOrExpr)
          when "expression" then @setVariableToExpr(name, valueOrExpr)
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
        @variables[name] = null
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

    evaluateNumericExpression: (tokens, varsInEvaluation = {}) ->
      return @evaluateExpression(tokens, varsInEvaluation)

    evaluateStringExpression: (tokens, varsInEvaluation = {}) ->
      return @evaluateExpression(tokens, varsInEvaluation)


  return exports = { VariableManager }