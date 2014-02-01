###
Action Handler
=================
A action handler can execute action for the Rule System. For actions and rule explenations
take a look at the [rules file](rules.html).
###

__ = require("i18n").__
Q = require 'q'
assert = require 'cassert'
_ = require('lodash')
S = require('string')
M = require './matcher'

###
The Action Handler
----------------
The base class for all Action Handler. If you want to provide actions in your plugin then 
you should create a sub class that implements a `executeAction` function.
###
class ActionHandler

  # ### executeAction()
  ###
  This function is executed by the rule system for every action on an rule. If the Action Handler
  can execute the Action it should return a promise that gets fulfilled with describing string,
  that explains what was done or would be done.

  If `simulate` is `true` the Action Handler should not execute the action. It should just
  return a promise fulfilled with a descrbing string like "would _..._".

  If the Action Handler can't handle the action (the string is not in the right format) then it
  should return `null`.

  Take a look at the Log Action Handler for a simple example.
  ###
  executeAction: (actionString, simulate, context) =>
    throw new Error("should be implemented by a subclass")  

env = null

###
The Log Action Handler
-------------
Provides log action, so that rules can use `log "some string"` in the actions part. It just prints
the given string to the logger.
###
class LogActionHandler extends ActionHandler

  constructor: (_env, @framework) ->
    env = _env

  # ### executeAction()
  ###
  This function handles action in the form of `log "some string"`
  ###
  executeAction: (actionString, simulate, context) ->
    stringToLog = null
    retVal = null
    # Parse the actionString: "log " -> '"' -> someString -> '"'
    M(actionString, context).match("log ").matchString((m, str) =>
      stringToLog = str
    ).onEnd(->
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        retVal = Q __("would log \"%s\"", stringToLog)
      else
        # else we should log the string.
        # But we don't do this because the framework logs the description anyway. So we would 
        # doubly log it.
        #env.logger.info stringToLog
        retVal = Q(stringToLog)
    )
    return retVal

###
The Switch Action Handler
-------------
Provides the ability to switch devices on or off. Currently it handles the following actions:

* switch [the] _device_ on|off
* turn [the] _device_ on|off
* switch on|off [the] _device_ 
* turn on|off [the] _device_ 

where _device_ is the name or id of a device and "the" is optional.
###
class SwitchActionHandler extends ActionHandler

  constructor: (_env, @framework) ->
    env = _env

  # ### executeAction()
  ###
  Handles the above actions.
  ###
  executeAction: (actionString, simulate, context) =>
    # The result the function will return:
    retVar = null

    switchDevices = _(@framework.devices).values().filter( 
      (device) => device.hasAction("turnOn") and device.hasAction("turnOff") 
    ).value()
    # Try to match the input string with:
    m = M(actionString, context).match(['turn ', 'switch '])

    device = null
    state = null
    fullMatchCount = 0

    # device name -> on|off
    m.matchDevice(switchDevices, (m, d) ->
      device = d
      m.match([' on', ' off'], (m, s) ->
        state = s.trim()
        m.onEnd( -> fullMatchCount++)
      )
    )

    # on|off -> deviceName
    m.match(['on ', 'off '], (m, s) ->
      state = s.trim()
      m.matchDevice(switchDevices, (m, d) ->
        device = d
        m.onEnd( -> fullMatchCount++)
      )
    )

    if fullMatchCount is 1
      state = (state is 'on')
      retVar = (
        if simulate
          if state then Q __("would turn %s on", device.name)
          else Q __("would turn %s off", device.name)
        else
          if state then device.turnOn().then( => __("turned %s on", device.name) )
          else device.turnOff().then( => __("turned %s off", device.name) )
      )
    else if fullMatchCount > 1
      context.addError(""""#{actionString.trim()}" is ambiguous.""")

    return retVar

# Export the classes so that they can be accessed by the framewor-
module.exports.ActionHandler = ActionHandler
module.exports.SwitchActionHandler = SwitchActionHandler
module.exports.LogActionHandler = LogActionHandler