###
Action Handler
=================
A action handler can execute action for the Rule System. For actions and rule explenations
take a look at the [rules file](rules.html).
###

__ = require("i18n").__
Q = require 'q'
assert = require 'cassert'

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

  If the simulate is true Action Handler should not execute the action. It should just
  return a promise fulfilled with a descrbing string like "would _..._".

  If the Action Handler can't handle the action (the string is not in the right format) then it
  should return `null`.

  Take a look at the Log Action Handler for a simple example.
  ###
  executeAction: (actionString, simulate) =>
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
  executeAction: (actionString, simulate) =>
    # If the action string matches the expected format
    regExpString = '^log\\s+"(.*)?"$'
    matches = actionString.match (new RegExp regExpString)
    if matches?
      # extract the string to log.
      stringToLog = matches[1]
      # If we should just simulate
      if simulate
        # just return a promise fulfilled with a description about what we would do.
        return Q __("would log \"%s\"", stringToLog)
      else
        # else log the string.
        env.logger.info stringToLog
        # We don't return a description in this case. Because it would be logged and we did logging
        # already. We don't want it to be dublicated outputted.
        #return Q __("logged \"%s\", stringToLog)
        return Q null

###
The Switch Action Handler
-------------
###
class SwitchActionHandler extends ActionHandler

  constructor: (_env, @framework) ->
    env = _env

  runOnDeviceByNameOrId: (deviceName, doCallback) ->
    self = this
    assert typeof self.framework.devices is 'object'
    for id, device of self.framework.devices
      if device.matchesIdOrName deviceName
        result = doCallback device
        #"break" when result was given by callback 
        if result? then return result

  executeAction: (actionString, simulate) =>
    actionString = actionString.toLowerCase()
    self = this
    result = null

    deviceName = null
    state = null
    regExpString = '^(?:turn|switch)?(?:\\s+the|\\s+)?(.+?)(on|off)$'
    matches = actionString.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      state = matches[2]
    else 
      # Try the other way around:
      regExpString = '^(?:turn|switch)\\s+(on|off)(?:\\s+the|\\s+)?(.+?)$'
      matches = actionString.match (new RegExp regExpString)
      if matches?
        deviceName = matches[2].trim()
        state = matches[1]
    # If we had a match
    if deviceName? and state?
      state = (state is "on")
      actionName = (if state then "turnOn" else "turnOff")
      result = self.runOnDeviceByNameOrId deviceName, (device)->
        if device.hasAction actionName
          if simulate
            if state
              return Q.fcall -> __("would turn %s on", device.name)
            else 
              return Q.fcall -> __("would turn %s off", device.name)
          else
            if state
              return device.turnOn().then( ->
                __("turned %s on", device.name)
              )
            else 
              return device.turnOff().then( ->
                __("turned %s off", device.name)
              )
        else return null
    return result

module.exports.ActionHandler = ActionHandler
module.exports.SwitchActionHandler = SwitchActionHandler
module.exports.LogActionHandler = LogActionHandler