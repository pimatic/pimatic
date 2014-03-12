###
Action Provider
=================
A Action Provider can parse a action of a rule string and returns an Action Handler for that.
The Action Handler offers a `executeAction` method to execute the action. 
For actions and rule explenations take a look at the [rules file](rules.html).
###

__ = require("i18n").__
Q = require 'q'
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

  ###
  The Log Action Provider
  -------------
  Provides log action, so that rules can use `log "some string"` in the actions part. It just prints
  the given string to the logger.
  ###
  class LogActionProvider extends ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) ->
      stringToLog = null
      fullMatch = no

      setLogString = (m, str) => stringToLog = str

      m = M(input, context)
        .match("log ")
        .matchString(setLogString)

      if m.hadMatches()
        match = m.getFullMatches()[0]
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new LogActionHandler(stringToLog)
        }
      else
        return null

  class LogActionHandler extends ActionHandler 

    constructor: (@stringToLog) ->

    executeAction: (simulate, context) ->
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return Q __("would log \"%s\"", @stringToLog)
      else
        # else we should log the string.
        # But we don't do this because the framework logs the description anyway. So we would 
        # doubly log it.
        #env.logger.info stringToLog
        return Q(@stringToLog)

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
          match = m.getFullMatches()[0]
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
          match = m.getFullMatches()[0]
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

    # ### executeAction()
    ###
    Handles the above actions.
    ###
    executeAction: (simulate) =>
      return (
        if simulate
          if @state then Q __("would turn %s on", @device.name)
          else Q __("would turn %s off", @device.name)
        else
          if @state then @device.turnOn().then( => __("turned %s on", @device.name) )
          else @device.turnOff().then( => __("turned %s off", @device.name) )
      )


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
      value = null
      match = null

      # Try to match the input string with:
      M(input, context)
        .match('dim ')
        .matchDevice(dimmers, (next, d) =>
          next.match(' to ')
            .matchNumber( (next, v) =>
              m = next.match('%', optional: yes)
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              value = v
              match = m.getLongestFullMatch()
            )
        )

      if match?
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
          actionHandler: new DimmerActionHandler(device, value)
        }
      else 
        return null

  class DimmerActionHandler extends ActionHandler

    constructor: (@device, value) ->

    # ### executeAction()
    ###
    Handles the above actions.
    ###
    executeAction: (simulate) =>
      return (
        if simulate
          Q __("would dim %s to %s%%", @device.name, @value)
        else
          @device.changeDimlevelTo(@value).then( => __("dimmed %s to %s%%", @device.name, @value) )
      )

  # Export the classes so that they can be accessed by the framework
  return exports = {
    ActionHandler
    ActionProvider
    SwitchActionProvider
    DimmerActionProvider
    LogActionProvider
  }