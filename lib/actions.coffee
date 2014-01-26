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

  If `simulate` is `true` the Action Handler should not execute the action. It should just
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
        # else we should log the string.
        # But we don't do this because the framework logs the description anyway. So we would 
        # doubly log it.
        #env.logger.info stringToLog
        return Q(stringToLog)
    else return null

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
  executeAction: (actionString, simulate) =>
    actionString = actionString.toLowerCase()
    self = this
    # The result the function will return:
    result = null
    # The potential device name:
    deviceName = null
    # the matched state: "on" or "off".
    state = null
    # Try to match the input string with:
    matches = actionString.match ///
      ^(?:turn|switch)? # Must begin with "turn" or "switch"
      \s+ #followed by whitespace
      # An optional "the " is handled in device.matchesIdOrName() we use later.
      (.+?) #followed by the device name or id,
      \s+ # whitespace
      (on|off)$ #and ends with "on" or "off".
    ///
    # If we have a match
    if matches?
      # then extract deviceName and state.
      deviceName = matches[1]
      state = matches[2]
    else 
      # Else try the other way around:
      matches = actionString.match ///
        ^(?:turn|switch) # Must begin with "turn" or "switch"
        \s+ # followed by whitespace
        # An optional "the " is handled in device.matchesIdOrName() we use later.
        (on|off) #and "on" or "off"
        \s+ # following whitespace
        ?(.+?)$ # and end with a device name.
        ///
      # If we have a match this time
      if matches?
        # then extract deviceName and state.
        deviceName = matches[2]
        state = matches[1]
    # If we had a one match of the two choice above
    if deviceName? and state?
      # then convert the state string to an boolean
      state = (state is "on")
      # and to the corresponding functions to execute.
      actionName = (if state then "turnOn" else "turnOff")

      # For all registed devices:
      for id, device of self.framework.devices
        do (id, device) =>
          # if we have not yet found a device
          unless result?
            # check if the device name of the current device matches 
            if device.matchesIdOrName deviceName
              # and the device has the "turnOn" or "turnOff" action
              if device.hasAction actionName
                # then simulate or do the action.
                result = (
                  if simulate
                    if state then Q __("would turn %s on", device.name)
                    else Q __("would turn %s off", device.name)
                  else
                    if state then device.turnOn().then( => __("turned %s on", device.name) )
                    else device.turnOff().then( => __("turned %s off", device.name) )
                )
    return result

# Export the classes so that they can be accessed by the framewor-
module.exports.ActionHandler = ActionHandler
module.exports.SwitchActionHandler = SwitchActionHandler
module.exports.LogActionHandler = LogActionHandler