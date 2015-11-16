###
Action Provider
=================
A Action Provider can parse a action of a rule string and returns an Action Handler for that.
The Action Handler offers a `executeAction` method to execute the action. 
For actions and rule explanations take a look at the [rules file](rules.html).
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
    This function should parse the given input string `input` and return an ActionHandler if 
    handled by the input of described action, otherwise it should return `null`.
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
      throw new Error("Should be implemented by a subclass")  

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

      varsAndFunsWriteable =  @framework.variableManager.getVariablesAndFunctions(readonly: false)
      M(input, context)
        .match("set ", optional: yes)
        .matchVariable(varsAndFunsWriteable, (next, variableName) =>
          next.match([" to ", " := ", " = "], (next) =>
            next.or([
              ( (next) =>
                  return next.matchNumericExpression( (next, rightTokens) => 
                    match = next.getFullMatch()
                    variableName = variableName.substring(1)
                    result = { variableName, rightTokens, match }
                  )
              ),
              ( (next) =>
                  return next.matchStringWithVars( (next, rightTokens) => 
                    match = next.getFullMatch()
                    variableName = variableName.substring(1)
                    result = { variableName, rightTokens, match }
                  )
              )
            ])
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
        return @framework.variableManager.evaluateExpression(@rightTokens).then( (value) =>
          @framework.variableManager.setVariableToValue(@variableName, value)
          return Promise.resolve("set $#{@variableName} to #{value}")
        )

        
  ###
  The SetPresence ActionProvider
  -------------
  Provides set presence action, so that rules can use `set presence of <device> to present|absent` 
  in the actions part.
  ###
  class SetPresenceActionProvider extends ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) ->
      retVar = null

      presenceDevices = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("changePresenceTo")
      ).value()
      
      device = null
      state = null
      match = null
      
      m = M(input, context).match(['set presence of '])
      
      m.matchDevice(presenceDevices, (m, d) ->
        m.match([' present', ' absent'], (m, s) ->
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
        assert state in ['present', 'absent']
        assert typeof match is "string"
        state = (state is 'present')
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new PresenceActionHandler(device, state)
        }
      else
        return null
        
  class PresenceActionHandler extends ActionHandler 

    constructor: (@device, @state) ->

    ###
    Handles the above actions.
    ###
    _doExectuteAction: (simulate, state) =>
      return (
        if simulate
          if state then Promise.resolve __("would set presence of %s to present", @device.name)
          else Promise.resolve __("would set presence of %s to absent", @device.name)
        else
          if state then @device.changePresenceTo(state).then( => 
            __("set presence of %s to present", @device.name) )
          else @device.changePresenceTo(state).then( => 
            __("set presence %s to absent", @device.name) )
      )

    # ### executeAction()
    executeAction: (simulate) => @_doExectuteAction(simulate, @state)
    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => @_doExectuteAction(simulate, (not @state))

  ###
  The open/close ActionProvider
  -------------
  Provides open/close action, for the DummyContactSensor.
  ###
  class ContactActionProvider extends ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) ->
      retVar = null

      contactDevices = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("changeContactTo")
      ).value()
      
      device = null
      state = null
      match = null
      
      m = M(input, context).match(['open ', 'close '], (m, a) =>
        m.matchDevice(contactDevices, (m, d) ->
          if device? and device.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          device = d
          state = a.trim()
          match = m.getFullMatch()
        )
      )
      
      if match?
        assert device?
        assert state in ['open', 'close']
        assert typeof match is "string"
        state = (state is 'close')
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ContactActionHandler(device, state)
        }
      else
        return null


  class ContactActionHandler extends ActionHandler 

    constructor: (@device, @state) ->

    ###
    Handles the above actions.
    ###
    _doExectuteAction: (simulate, state) =>
      return (
        if simulate
          if state then Promise.resolve __("would set contact %s to closed", @device.name)
          else Promise.resolve __("would set contact %s to opened", @device.name)
        else
          if state then @device.changeContactTo(state).then( =>
            __("set contact %s to closed", @device.name) )
          else @device.changeContactTo(state).then( =>
            __("set contact %s to opened", @device.name) )
      )

    # ### executeAction()
    executeAction: (simulate) => @_doExectuteAction(simulate, @state)
    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => @_doExectuteAction(simulate, (not @state))

        
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

      switchDevices = _(@framework.deviceManager.devices).values().filter( 
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
  The Toggle Action Provider
  -------------
  Provides the ability to toggle switch devices on or off. 
  Currently it handles the following actions:

  * toggle the state of _device_
  * toggle the state of [the] _device_
  * toggle _device_ state 
  * toggle  [the] _device_ state

  where _device_ is the name or id of a device and "the" is optional.
  ###
  class ToggleActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      switchDevices = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("toggle")
      ).value()

      if switchDevices.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('toggle ')
        .or([
          ( (m) => 
            return m.match('the state of ', optional: yes)
              .matchDevice(switchDevices, onDeviceMatch)
          ),
          ( (m) => 
            return m.matchDevice(switchDevices, (m, d) ->
              return m.match(' state', optional: yes, (m)-> onDeviceMatch(m, d) )
            )
          )
        ])
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ToggleActionHandler(device)
        }
      else
        return null

  class ToggleActionHandler extends ActionHandler

    constructor: (@device) -> #nop

    # ### executeAction()
    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would toggle state of %s", @device.name)
        else
          @device.toggle().then( => __("toggled state of %s", @device.name) )
      )

  ###
  The Button Action Provider
  -------------
  Provides the ability to press the button of a buttonsdevices.
  Currently it handles the following actions:

  * press [the] _device_

  where _device_ is the name or id of a the button not the buttons device and "the" is optional.
  ###
  class ButtonActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      matchCount = 0
      matchingDevice = null
      matchingButtonId = null
      end = () => matchCount++
      onButtonMatch = (m, {device, buttonId}) =>
        matchingDevice = device
        matchingButtonId = buttonId

      buttonsWithId = [] 

      for id, d of @framework.deviceManager.devices
        continue unless d instanceof env.devices.ButtonsDevice
        for b in d.config.buttons
          buttonsWithId.push [{device: d, buttonId: b.id}, b.id]
          buttonsWithId.push [{device: d, buttonId: b.id}, b.text] if b.id isnt b.text

      m = M(input, context)
        .match('press ')
        .match('the ', optional: true)
        .match('button ', optional: true)
        .match(
          buttonsWithId, 
          wildcard: "{button}",
          onButtonMatch
        )

      match = m.getFullMatch()
      if match?
        assert matchingDevice?
        assert matchingButtonId?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new ButtonActionHandler(matchingDevice, matchingButtonId)
        }
      else
        return null

  class ButtonActionHandler extends ActionHandler

    constructor: (@device, @buttonId) ->
      assert @device? and @device instanceof env.devices.ButtonsDevice
      assert @buttonId? and typeof @buttonId is "string"

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate) =>
      return (
        if simulate
          Promise.resolve __("would press button %s of device %s", @buttonId, @device.id)
        else
          @device.buttonPressed(@buttonId)
            .then( =>__("press button %s of device %s", @buttonId, @device.id) )
      )

    # ### executeAction()
    executeAction: (simulate) => @_doExecuteAction(simulate)
    # ### hasRestoreAction()
    hasRestoreAction: -> no

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

      shutterDevices = _(@framework.deviceManager.devices).values().filter( 
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

      shutterDevices = _(@framework.deviceManager.devices).values().filter( 
        # only match Shutter devices and not media players
        (device) => device.hasAction("stop") and device.hasAction("moveUp")
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

      dimmers = _(@framework.deviceManager.devices).values().filter( 
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


  class HeatingThermostatModeActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      thermostats = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("changeModeTo") 
      ).value()

      if thermostats.length is 0 then return

      device = null
      valueTokens = null
      match = null

      # Try to match the input string with:
      M(input, context)
        .match('set mode of ')
        .matchDevice(thermostats, (next, d) =>
          next.match(' to ')
            .matchStringWithVars( (next, ts) =>
              m = next.match(' mode', optional: yes)
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
          modes = ["eco", "boost", "auto", "manu", "comfy"] 
          # TODO: Implement eco & comfy in changeModeTo method!
          if modes.indexOf(value) < -1
            context?.addError("Allowed modes: eco,boost,auto,manu,comfy")
            return
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new HeatingThermostatModeActionHandler(@framework, device, valueTokens)
        }
      else 
        return null


  class HeatingThermostatModeActionHandler extends ActionHandler

    constructor: (@framework, @device, @valueTokens) ->
      assert @device?
      assert @valueTokens?

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate, value) =>
      return (
        if simulate
          __("would set mode %s to %s", @device.name, value)
        else
          @device.changeModeTo(value).then( => __("set mode %s to %s", @device.name, value) )
      )

    # ### executeAction()
    executeAction: (simulate) => 
      @framework.variableManager.evaluateStringExpression(@valueTokens).then( (value) =>
        @lastValue = value
        return @_doExecuteAction(simulate, value)
      )

    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => Promise.resolve(@_doExecuteAction(simulate, @lastValue))



  class HeatingThermostatSetpointActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>
      # The result the function will return:
      retVar = null

      thermostats = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("changeTemperatureTo") 
      ).value()

      if thermostats.length is 0 then return

      device = null
      valueTokens = null
      match = null

      # Try to match the input string with:
      M(input, context)
        .match('set temp of ')
        .matchDevice(thermostats, (next, d) =>
          next.match(' to ')
            .matchNumericExpression( (next, ts) =>
              m = next.match('°C', optional: yes)
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
            context?.addError("Can't set temp to a negativ value.")
            return
          if value > 32.0
            context?.addError("Can't set temp higher than 32°C.")
            return
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new HeatingThermostatSetpointActionHandler(@framework, device, valueTokens)
        }
      else 
        return null

  class HeatingThermostatSetpointActionHandler extends ActionHandler

    constructor: (@framework, @device, @valueTokens) ->
      assert @device?
      assert @valueTokens?

    # _clampVal: (value) ->
    #   assert(not isNaN(value))
    #   return (switch
    #     when value > 32 then 32
    #     when value < 0 then 0
    #     else value
    #   )

    ###
    Handles the above actions.
    ###
    _doExecuteAction: (simulate, value) =>
      return (
        if simulate
          __("would set temp of %s to %s°C", @device.name, value)
        else
          @device.changeTemperatureTo(value).then( => 
            __("set temp of %s to %s°C", @device.name, value) 
          )
      )

    # ### executeAction()
    executeAction: (simulate) => 
      @framework.variableManager.evaluateNumericExpression(@valueTokens).then( (value) =>
        # value = @_clampVal value
        @lastValue = value
        return @_doExecuteAction(simulate, value)
      )

    # ### hasRestoreAction()
    hasRestoreAction: -> yes
    # ### executeRestoreAction()
    executeRestoreAction: (simulate) => Promise.resolve(@_doExecuteAction(simulate, @lastValue))


  ###
  The Timer Action Provider
  -------------
  Start, stop or reset Timer

  * start|stop|reset the _device_ [timer] 

  where _device_ is the name or id of a timer device and "the" is optional.
  ###
  class TimerActionProvider extends ActionProvider

    constructor: (@framework) ->

    # ### parseAction()
    ###
    Parses the above actions.
    ###
    parseAction: (input, context) =>

      timerDevices = _(@framework.deviceManager.devices).values().filter( 
        (device) => (
          device.hasAction("startTimer") and 
          device.hasAction("stopTimer") and 
          device.hasAction("resetTimer") 
        )
      ).value()

      device = null
      action = null
      match = null

      # Try to match the input string with: start|stop|reset ->
      m = M(input, context).match(['start ', 'stop ', 'reset '], (m, a) =>
        # device name -> up|down
        m.matchDevice(timerDevices, (m, d) ->
          last = m.match(' timer', {optional: yes})
          if last.hadMatch()
             # Already had a match with another device?
            if device? and device.id isnt d.id
              context?.addError(""""#{input.trim()}" is ambiguous.""")
              return
            device = d
            action = a.trim()
            match = last.getFullMatch()
        )
      )

      if match?
        assert device?
        assert action in ['start', 'stop', 'reset']
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new TimerActionHandler(device, action)
        }
      
        return null

  class TimerActionHandler extends ActionHandler

    constructor: (@device, @action) ->

    # ### executeAction()
    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would #{@action} %s", @device.name)
        else
          @device["#{@action}Timer"]().then( => __("#{@action}ed %s", @device.name) )
      )
    # ### hasRestoreAction()
    hasRestoreAction: -> false

  # Pause play volume actions
  class AVPlayerPauseActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `play device`
    ###
    parseAction: (input, context) =>

      retVar = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("pause") 
      ).value()

      if avPlayers.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('pause ')
        .matchDevice(avPlayers, onDeviceMatch)
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerPauseActionHandler(device)
        }
      else
        return null

  class AVPlayerPauseActionHandler extends ActionHandler

    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would pause %s", @device.name)
        else
          @device.pause().then( => __("paused %s", @device.name) )
      )
      
  # stop play volume actions
  class AVPlayerStopActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        # only match media players and not shutters
        (device) => device.hasAction("stop") and device.hasAction("play")
      ).value()

      if avPlayers.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('stop ')
        .matchDevice(avPlayers, onDeviceMatch)
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerStopActionHandler(device)
        }
      else
        return null

  class AVPlayerStopActionHandler extends ActionHandler

    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would stop %s", @device.name)
        else
          @device.stop().then( => __("stop %s", @device.name) )
      )

  class AVPlayerPlayActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("play") 
      ).value()

      if avPlayers.length is 0 then return

      device = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match('play ')
        .matchDevice(avPlayers, onDeviceMatch)
        
      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerPlayActionHandler(device)
        }
      else
        return null
        
  class AVPlayerPlayActionHandler extends ActionHandler

    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would play %s", @device.name)
        else
          @device.play().then( => __("playing %s", @device.name) )
      )

  class AVPlayerVolumeActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null
      volume = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("setVolume") 
      ).value()

      if avPlayers.length is 0 then return

      device = null
      valueTokens = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      M(input, context)
        .match('change volume of ')
        .matchDevice(avPlayers, (next,d) =>
          next.match(' to ', (next) =>
            next.matchNumericExpression( (next, ts) =>
              m = next.match('%', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              valueTokens = ts
              match = m.getFullMatch()
            )
          )
        )

        
      if match?
        value = valueTokens[0] 
        assert device?
        assert typeof match is "string"
        value = parseFloat(value)
        if value < 0.0
          context?.addError("Can't change volume to a negativ value.")
          return
        if value > 100.0
          context?.addError("Can't change volume to greater than 100%.")
          return
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerVolumeActionHandler(@framework,device,valueTokens)
        }
      else
        return null
        
  class AVPlayerVolumeActionHandler extends ActionHandler

    constructor: (@framework, @device, @valueTokens) -> #nop

    executeAction: (simulate, value) => 
      return (
        if isNaN(@valueTokens[0])
          val = @framework.variableManager.getVariableValue(@valueTokens[0].substring(1))
        else
          val = @valueTokens[0]     
        if simulate
          Promise.resolve __("would set volume of %s to %s", @device.name, val)
        else   
          @device.setVolume(val).then( => __("set volume of %s to %s", @device.name, val) )
      )   

  class AVPlayerNextActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null
      volume = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("next") 
      ).value()

      if avPlayers.length is 0 then return

      device = null
      valueTokens = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match(['play next', 'next '])
        .match(" song ", optional: yes)
        .match("on ", optional: yes)
        .matchDevice(avPlayers, onDeviceMatch)

      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerNextActionHandler(device)
        }
      else
        return null
        
  class AVPlayerNextActionHandler extends ActionHandler
    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would play next track of %s", @device.name)
        else
          @device.next().then( => __("play next track of %s", @device.name) )
      )      

  class AVPlayerPrevActionProvider extends ActionProvider 
  
    constructor: (@framework) -> 
    # ### executeAction()
    ###
    This function handles action in the form of `execute "some string"`
    ###
    parseAction: (input, context) =>

      retVar = null
      volume = null

      avPlayers = _(@framework.deviceManager.devices).values().filter( 
        (device) => device.hasAction("previous") 
      ).value()

      if avPlayers.length is 0 then return

      device = null
      valueTokens = null
      match = null

      onDeviceMatch = ( (m, d) -> device = d; match = m.getFullMatch() )

      m = M(input, context)
        .match(['play previous', 'previous '])
        .match(" song ", optional: yes)
        .match("on ", optional: yes)
        .matchDevice(avPlayers, onDeviceMatch)

      if match?
        assert device?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new AVPlayerNextActionHandler(device)
        }
      else
        return null
        
  class AVPlayerPrevActionHandler extends ActionHandler
    constructor: (@device) -> #nop

    executeAction: (simulate) => 
      return (
        if simulate
          Promise.resolve __("would play previous track of %s", @device.name)
        else
          @device.previous().then( => __("play previous track of %s", @device.name) )
      ) 
         



  # Export the classes so that they can be accessed by the framework
  return exports = {
    ActionHandler
    ActionProvider
    SetVariableActionProvider
    SetPresenceActionProvider
    ContactActionProvider
    SwitchActionProvider
    DimmerActionProvider
    LogActionProvider
    ShutterActionProvider
    StopShutterActionProvider
    ToggleActionProvider
    ButtonActionProvider
    HeatingThermostatModeActionProvider
    HeatingThermostatSetpointActionProvider
    TimerActionProvider
    AVPlayerPauseActionProvider
    AVPlayerStopActionProvider
    AVPlayerPlayActionProvider
    AVPlayerVolumeActionProvider
    AVPlayerNextActionProvider
    AVPlayerPrevActionProvider
  }
