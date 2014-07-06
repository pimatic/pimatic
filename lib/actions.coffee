###
Action Provider
=================
A Action Provider can parse a action of a rule string and returns an Action Handler for that.
The Action Handler offers a `executeAction` method to execute the action. 
For actions and rule explenations take a look at the [rules file](rules.html).
###

__ = require("i18n").__
Promise = require 'bluebird'
assert = require 'cassert'
_ = require('lodash')
S = require('string')
M = require './matcher'

module.exports = (env) ->

  ###
  The ActionProvider
  ----------------
  The base class for all Action Providers. If you want to provide actions in your plugin then 
  you should create a sub class that implements the `parseAction` function.
  ###
  class ActionProvider

    # ### parseAction()
    ###
    This function should parse the given input string `input` and return a ActionHandler if 
    it can handle the by the input described action else it should return `null`.
    ###
    parseAction: (input, context) => 
      throw new Error("Your ActionProvider must implement parseAction")

  ###
  The Action Handler
  ----------------
  The base class for all Action Handler. If you want to provide actions in your plugin then 
  you should create a sub class that implements a `executeAction` function.
  ###
  class ActionHandler

    # ### executeAction()
    ###
    Ìt should return a promise that gets fulfilled with describing string, that explains what was 
    done or would be done.

    If `simulate` is `true` the Action Handler should not execute the action. It should just
    return a promise fulfilled with a descrbing string like "would _..._".

    Take a look at the Log Action Handler for a simple example.
    ###
    executeAction: (simulate) =>
      throw new Error("should be implemented by a subclass")  

    hasRestoreAction: => no

    executeRestoreAction: (simulate) =>
      throw new Error(
        "executeRestoreAction must be implemented when hasRestoreAction returns true"
      )  

  ###
  The Log Action Provider
  -------------
  Provides log action, so that rules can use `log "some string"` in the actions part. It just prints
  the given string to the logger.
  ###
  class LogActionProvider extends ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) ->
      stringToLogTokens = null
      fullMatch = no

      setLogString = (m, tokens) => stringToLogTokens = tokens

      m = M(input, context)
        .match("log ")
        .matchStringWithVars(setLogString)

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new LogActionHandler(@framework, stringToLogTokens)
        }
      else
        return null

  class LogActionHandler extends ActionHandler 

    constructor: (@framework, @stringToLogTokens) ->

    executeAction: (simulate, context) ->
      @framework.variableManager.evaluateStringExpression(@stringToLogTokens).then( (strToLog) =>
        if simulate
          # just return a promise fulfilled with a description about what we would do.
          return __("would log \"%s\"", strToLog)
        else
          # else we should log the string.
          # But we don't do this because the framework logs the description anyway. So we would 
          # doubly log it.
          #env.logger.info stringToLog
          return strToLog
      )


  ###
  The SetVariable ActionProvider
  -------------
  Provides log action, so that rules can use `log "some string"` in the actions part. It just prints
  the given string to the logger.
  ###
  class SetVariableActionProvider extends ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) ->
      result = null

      allVars = @framework.variableManager.variables
      varsRight = _(allVars).map( (v) => v.name ).valueOf()
      varsLeft = _(allVars).filter( (v) => not v.readonly ).map( (v) => v.name ).valueOf()

      M(input, context)
        .match("set ", optional: yes)
        .matchVariable(varsLeft, (next, variableName) =>
          next.match([" to ", " := ", " = "], (next) =>
            next.matchNumericExpression(varsRight, (next, rightTokens) => 
              match = next.getFullMatch()
              variableName = variableName.substring(1)
              result = { variableName, rightTokens, match }
            )
          )
        )

      if result?
        variables = @framework.variableManager.extractVariables(result.rightTokens)
        unless @framework.variableManager.isVariableDefined(result.variableName)
          context.addError("Variable $#{result.variableName} is not defined.")
          return null
        for v in variables?
          unless @framework.variableManager.isVariableDefined(v)
            context.addError("Variable $#{v} is not defined.")
            return null
        return {
          token: result.match
          nextInput: input.substring(result.match.length)
          actionHandler: new SetVariableActionHandler(
            @framework, result.variableName, result.rightTokens
          )
        }
      else
        return null

  class SetVariableActionHandler extends ActionHandler 

    constructor: (@framework, @variableName, @rightTokens) ->

    executeAction: (simulate, context) ->
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return Promise.resolve __("would set $%s to value of %s", @variableName, 
          _(@rightTokens).reduce( (left, right) => "#{left} #{right}" )
        )
      else
        return @framework.variableManager.evaluateNumericExpression(@rightTokens).then( (value) => 
          @framework.variableManager.setVariableToValue(@variableName, value)
          return Promise.resolve("set $#{@variableName} to #{value}")
        )



  ###
  The Switch Action Provider
  -------------
  Provides the ability to switch devices on or off. Currently it handles the following actions:

  * switch [the] _device_ on|off
  * turn [the] _device_ on|off
  * switch on|off [the] _device_ 
  * turn on|off [the] _device_ 

  where _device_ is the name or id of a device and "the" is optional.
  ###
  class SwitchActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      switchDevices = _(@framework.devices).values().filter( 
        (device) => device.hasAction("turnOn") and device.hasAction("turnOff") 
      ).value()

      device = null
      state = null
      match = null

      # Try to match the input string with: turn|switch ->
      m = M(input, context).match(['turn ', 'switch '])

      # device name -> on|off
      m.matchDevice(switchDevices, (m, d) ->
        m.match([' on', ' off'], (m, s) ->
          # Already had a match with another device?
          if device? and device.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          device = d
          state = s.trim()
          match = m.getFullMatch()
        )
      )

      # on|off -> deviceName
      m.match(['on ', 'off '], (m, s) ->
        m.matchDevice(switchDevices, (m, d) ->
          # Already had a match with another device?
          if device? and device.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          device = d
          state = s.trim()
          match = m.getFullMatch()
        )
      )

      if match?
        assert device?
        assert state in ['on', 'off']
        assert typeof match is "string"
        state = (state is 'on')
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new SwitchActionHandler(device, state)
        }
      else
        return null

  class SwitchActionHandler extends ActionHandler

    constructor: (@device, @state) ->

    ###
    Handles the above actions.
    ###
    _doExectuteAction: (simulate, state) =>
      return (
        if simulate
          if state then Promise.resolve __("would turn %s on", @device.name)
          else Promise.resolve __("would turn %s off", @device.name)
        else
          if state then @device.turnOn().then( => __("turned %s on", @device.name) )
          else @device.turnOff().then( => __("turned %s off", @device.name) )
      )

    # ### executeAction()
    executeAction: (simulate) => @_doExectuteAction(simulate, @state)
    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => @_doExectuteAction(simulate, (not @state))



  ###
  The Shutter Action Provider
  -------------
  Provides the ability to raise or lower a shutter

  * lower [the] _device_ [down]
  * raise [the] _device_ [up]
  * move [the] _device_ up|down

  where _device_ is the name or id of a device and "the" is optional.
  ###
  class ShutterActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>

      shutterDevices = _(@framework.devices).values().filter( 
        (device) => device.hasAction("moveUp") and device.hasAction("moveDown") 
      ).value()

      device = null
      position = null
      match = null

      # Try to match the input string with: raise|up ->
      m = M(input, context).match(['raise ', 'lower ', 'move '], (m, a) =>
        # device name -> up|down
        m.matchDevice(shutterDevices, (m, d) ->
          [p, nt] = (
            switch a.trim() 
              when 'raise' then ['up', ' up']
              when 'lower' then ['down', ' down']
              else [null, [" up", " down"] ]
          )
          last = m.match(nt, {optional: a.trim() isnt 'move'}, (m, po) ->
            p = po.trim()
          )
          if last.hadMatch()
             # Already had a match with another device?
            if device? and device.id isnt d.id
              context?.addError(""""#{input.trim()}" is ambiguous.""")
              return
            device = d
            position = p
            match = last.getFullMatch()
        )
      )

      if match?
        assert device?
        assert position in ['down', 'up']
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ShutterActionHandler(device, position)
        }
      else
        return null

  class ShutterActionHandler extends ActionHandler

    constructor: (@device, @position) ->

    # ### executeAction()
    executeAction: (simulate) => 
      return (
        if simulate
          if @position is 'up' then Promise.resolve __("would raise %s", @device.name)
          else Promise.resolve __("would lower %s", @device.name)
        else
          if @position is 'up' then @device.moveUp().then( => __("raised %s", @device.name) )
          else @device.moveDown().then( => __("lowered %s", @device.name) )
      )
    # ### hasRestoreAction()
    hasRestoreAction: -> @device.hasAction('stop')
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => 
      if simulate then Promise.resolve __("would stop %s", @device.name)
      else @device.stop().then( =>  __("stopped %s", @device.name) )

  ###
  The Shutter Stop Action Provider
  -------------
  Provides the ability to stop a shutter

  * stop [the] _device_

  where _device_ is the name or id of a device and "the" is optional.
  ###
  class StopShutterActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>

      shutterDevices = _(@framework.devices).values().filter( 
        (device) => device.hasAction("stop") 
      ).value()

      device = null
      match = null

      # Try to match the input string with: stop ->
      m = M(input, context).match("stop ", (m, a) =>
        # device name -> up|down
        m.matchDevice(shutterDevices, (m, d) ->
          # Already had a match with another device?
          if device? and device.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          device = d
          match = m.getFullMatch()
        )
      )

      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new StopShutterActionHandler(device)
        }
      else
        return null

  class StopShutterActionHandler extends ActionHandler

    constructor: (@device) ->

    # ### executeAction()
    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would stop %s", @device.name)
        else
          @device.stop().then( => __("stopped %s", @device.name) )
      )
    # ### hasRestoreAction()
    hasRestoreAction: -> false

  ###
  The Dimmer Action Provider
  -------------
  Provides the ability to change the dim level of dimmer devices. Currently it handles the 
  following actions:

  * dim [the] _device_ to _value_%

  where _device_ is the name or id of a device and "the" is optional.
  ###
  class DimmerActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      dimmers = _(@framework.devices).values().filter( 
        (device) => device.hasAction("changeDimlevelTo") 
      ).value()

      if dimmers.length is 0 then return

      device = null
      valueTokens = null
      match = null

      # Try to match the input string with:
      M(input, context)
        .match('dim ')
        .matchDevice(dimmers, (next, d) =>
          next.match(' to ')
            .matchNumericExpression( (next, ts) =>
              m = next.match('%', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              valueTokens = ts
              match = m.getFullMatch()
            )
        )

      if match?
        if valueTokens.length is 1 and not isNaN(valueTokens[0])
          value = valueTokens[0] 
          assert(not isNaN(value))
          value = parseFloat(value)
          if value < 0.0
            context?.addError("Can't dim to a negativ dimlevel.")
            return
          if value > 100.0
            context?.addError("Can't dim to greaer than 100%.")
            return
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new DimmerActionHandler(@framework, device, valueTokens)
        }
      else 
        return null

  class DimmerActionHandler extends ActionHandler

    constructor: (@framework, @device, @valueTokens) ->
      assert @device?
      assert @valueTokens?

    _clampVal: (value) ->
      assert(not isNaN(value))
      return (switch
        when value > 100 then 100
        when value < 0 then 0
        else value
      )

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate, value) =>
      return (
        if simulate
          __("would dim %s to %s%%", @device.name, value)
        else
          @device.changeDimlevelTo(value).then( => __("dimmed %s to %s%%", @device.name, value) )
      )

    # ### executeAction()
    executeAction: (simulate) => 
      @framework.variableManager.evaluateNumericExpression(@valueTokens).then( (value) =>
        value = @_clampVal value
        @lastValue = value
        return @_doExecuteAction(simulate, value)
      )

    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => Promise.resolve(@_doExecuteAction(simulate, @lastValue))

  # Export the classes so that they can be accessed by the framework
  return exports = {
    ActionHandler
    ActionProvider
    SetVariableActionProvider
    SwitchActionProvider
    DimmerActionProvider
    LogActionProvider
    ShutterActionProvider
    StopShutterActionProvider
  }