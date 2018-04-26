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
        "#{@_device.id}.#{@_attrName}", 
        'attribute', 
        @_device.attributes[@_attrName].unit, 
        yes
      )
      @_addListener()

    _addListener: () ->
      @_device.on(@_attrName, @_attrListener = (value) => @_setValue(value) )
      @_device.on('changed', @_deviceChangedListener = (newDevice) =>
        if newDevice.hasAttribute(@_attrName)
          @unit = newDevice.attributes[@_attrName].unit
          @_removeListener()
          @_device = newDevice
          @_addListener()
        else
          @_vars._removeDeviceAttributeVariable(@name)
      )
      @_device.on('destroyed', @_deviceDestroyedListener = =>
        @_vars._removeDeviceAttributeVariable(@name)
      )

    _removeListener: () ->
      @_device.removeListener(@_attrName, @_attrListener)
      @_device.removeListener("changed", @_deviceChangedListener)
      @_device.removeListener("destroyed", @_deviceDestroyedListener)
      
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
        description: """
          Returns the lowest-valued number of the numeric expressions
          passed to it. If any parameter isn't a number and can't be
          converted into one the "null" value is returned.
        """
        args:
          numbers:
            description: """
              Zero or more numeric expressions among which the
              lowest value will be selected and returned. If no expression
              is provided the null value is returned
            """
            type: "number"
            multiple: yes
        exec: (args...) -> _.reduce(_.map(args, parseFloat), (a, b) -> Math.min(a,b) )
      max:
        description: """
          Returns the highest-valued number of the numeric expressions
          passed to it. If any parameter isn't a number and can't be
          converted into one the "null" value is returned
        """
        args:
          numbers:
            description: """
              Zero or more numeric expressions among which the
              highest value will be selected and returned. If no expression
              is provided the null value is returned
            """
            type: "number"
            multiple: yes
        exec: (args...) -> _.reduce(_.map(args, parseFloat), (a, b) -> Math.max(a,b) )
      avg:
        description: """
          Returns the average (arithmetic mean) for the numeric
          expressions passed to it. If any parameter isn't a number
          and can't be converted into one the "null" value is returned
        """
        args:
          numbers:
            description: """
              Zero or more numeric expressions among which the
              average is calculated. If no expression
              is provided the null value is returned
            """
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
      pow:
        description: "Returns the base to the exponent power"
        args:
          base:
            description: "A numeric expression for base number"
            type: "number"
          exponent:
            description: "A numeric expression the exponent. If omitted base 2 is applied"
            type: "number"
            optional: yes
        exec: (base, exponent=2) ->
          return Math.pow(base, exponent)
      abs:
        description: """
          Returns the absolute value of a number
        """
        args:
          x:
            description: "A numeric expression"
            type: "number"
        exec: (x) ->
          return Math.abs(x)
      sign:
        description: """
          Returns the sign of the value evaluated from the given
          numeric expression, indicating whether
          the number is positive (1), negative (-1) or zero (0)
        """
        args:
          x:
            description: "A numeric expression"
            type: "number"
        exec: (x) ->
          return Math.sign(x)
      sqrt:
        description: "Returns the square root of a number"
        args:
          x:
            description: "A numeric expression"
            type: "number"
        exec: (x) ->
          return Math.sqrt(x)
      cos:
        description: "Returns the cosine of a number"
        args:
          x:
            description: "A numeric expression for the radians"
            type: "number"
        exec: (x) ->
          return Math.cos(x)
      acos:
        description: """
          Returns the arccosine (in radians) of a number
          if it's between -1 and 1; otherwise, NaN
        """
        args:
          x:
            description: "A numeric expression"
            type: "number"
        exec: (x) ->
          return Math.acos(x)
      log:
        description: """
          Returns the logarithm for a given
          number and base. If no base is provided,
          the logarithmus naturalis (base e) is assumed.
        """
        args:
          x:
            description: "A numeric expression"
            type: "number"
          base:
            description: "A numeric expression"
            type: "number"
            optional: yes
        exec: (x, base) ->
          return Math.log(x) / if base? then Math.log(base) else 1
      round:
        args:
          number:
            type: "number"
          decimals:
            type: "number"
            optional: yes
        exec: (value, decimals) ->
          multiplier = Math.pow(10, decimals ? 0)
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
      trunc:
        description: """
          Returns the given number truncated at at the given decimal
          place. If the decimal place is omitted or the value 0 is set, the
          integer part is returned by removing any fractional digits. Note, this
          function is equivalent to symmetrical rounding towards zero.
        """
        args:
          number:
            type: "number"
          decimals:
            type: "number"
            optional: yes
        exec: (value, decimals) ->
          multiplier = Math.pow(10, decimals ? 0)
          return Math.trunc(value * multiplier) / multiplier
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
      diffDate:
        description: """
          Returns the difference between to given date strings
          in milliseconds. Optionally, a format string can be
          provided to return the difference in "seconds",
          "minutes", "hours", "days". In this case the result is a real
          number (float) is returned.
        """
        args:
          startDate:
            type: "string"
            optional: no
          endDate:
            type: "string"
            optional: no
          format:
            type: "string"
            optional: yes
        exec: (startDate, endDate, format) ->
          diff = Date.parse(endDate) - Date.parse(startDate)
          switch format
            when "seconds"
              diff = diff / 1000
            when "minutes"
              diff = diff / 1000 / 60
            when "hours"
              diff = diff / 1000 / 60 / 60
            when "days"
              diff = diff / 1000 / 60 / 60 / 24
          return diff
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
            unit = this.units[0]
            info = humanFormat.raw(number, unit: unit)
            formatted = (if decimals? then Number(info.value).toFixed(decimals) else info.value)
            return "#{formatted}#{info.prefix}#{unit}"
          else
            unless decimals?
              decimals = 2
            formatted = Number(number).toFixed(decimals)
            return "#{formatted}#{unit}"
      hexString:
        description: """
          Converts a given number to a hex string
        """
        args:
          number:
            description: """
              The input number. Negative numbers will be treated as 32-bit
              signed integers. Thus, numbers smaller than -2147483648 will
              be cut off which is due to limitation of using bitwise operators
              in JavaScript. Positive integers will be handled up to 53-bit
              as JavaScript uses IEEE 754 double-precision floating point
              numbers, internally
            """
            type: "number"
          padding:
            description: """
              Specifies the (minimum) number of digits the resulting string
              shall contain. The string will be padded by prepending leading
              "0" digits, accordingly. By default, padding is set to 0 which
              means no padding is performed
            """
            type: "number"
            optional: yes
          prefix:
            description: """
              Specifies a prefix string which will be prepended to the
              resulting hex number. By default, no prefix is set
            """
            type: "string"
            optional: yes
        exec: (number, padding=0, prefix="") ->
          try
            padding = Math.max(Math.min(padding, 10), 0)
            hex = Number(if number < 0 then number >>> 0 else number).toString(16).toUpperCase()
            if hex.length < padding
              hex = Array(padding + 1 - hex.length).join('0') + hex
            return prefix + hex
          catch error
            env.logger.error "Error in hexString expression: #{error.message}"
            throw error
      subString:
        description: """
            Returns the substring of the given string matching the given regular expression
            and flags. If the global flag is used the resulting substring is a concatenation
            of all matches. If the expression contains capture groups the group matches will
            be concatenated to provide the resulting substring. If there is no match the
            empty string is returned
        """
        args:
          string:
            description: """
              The input string which is a string expression which may also contain variable
              references and function calls
            """
            type: "string"
          expression:
            description: "A string value which may contain a regular expression"
            type: "string"
          flags:
            description: """
              A string with flags for a regular expression: g: global match,
              i: ignore case
            """
            type: "string"
            optional: yes
        exec: (string, expression, flags) ->
          try
            matchResult = string.match new RegExp(expression, flags)
          catch error
            env.logger.error "Error in subString expression: #{error.message}"
            throw error

          if matchResult?
            if flags? and flags.includes('g')
             # concatenate all global matches
              _.reduce(matchResult, (fullMatch, val) -> fullMatch = fullMatch + val)
            else
              # concatenate all matched capture groups (if any) or prompt the match result
              if _.isString matchResult[1]
                matchResult.shift()
                _.reduce(matchResult, (fullMatch, val) ->
                  if _.isString val then fullMatch = fullMatch + val)
              else
                matchResult[0]
          else
            env.logger.debug "subString expression did not match"
            return ""
    }

    inited: false

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
      @inited = true
      @emit 'init'

    waitForInit: () ->
      return new Promise( (resolve) =>
        if @inited then return resolve()
        @once('init', resolve)
      )

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
      return (vars = (t.substring(1) for t in tokens when @isAVariable(t)))

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
