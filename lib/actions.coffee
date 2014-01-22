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
        # else log the string.
        env.logger.info stringToLog
        # We don't return a description in this case. Because it would be logged and we did logging
        # already. We don't want it to be dublicated outputted.
        #return Q __("logged \"%s\", stringToLog)
        return Q null

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


  executeAction: (actionString, simulate) =>
    actionString = actionString.toLowerCase()
    self = this
    result = null

    deviceName = null
    state = null
    matches = actionString.match ///
      ^(?:turn|switch)? # Must begin with "turn" or "switch"
      (?:\s+the\s+|\s+)? #followed by a " the " or a space
      (.+?) #followed by the device name or id,
      \s+ # a space
      (on|off)$ #and ends with "on" or "off"
    ///
    if matches?
      deviceName = matches[1].trim()
      state = matches[2]
    else 
      # Try the other way around:
      matches = actionString.match ///
        ^(?:turn|switch) # Must begin with "turn" or "switch"
        \s+ # folowed by a space
        (on|off) #and "on" or "off"
        (?:\s+the\s+|\s+) # a " the " or space
        ?(.+?)$ # and a device name
        ///
      if matches?
        deviceName = matches[2].trim()
        state = matches[1]
    # If we had a match
    if deviceName? and state?
      state = (state is "on")
      actionName = (if state then "turnOn" else "turnOff")

      for id, device of self.framework.devices
        do (id, device) =>
          unless result?
            if device.matchesIdOrName deviceName
              if device.hasAction actionName
                result = (
                  if simulate
                    if state then Q __("would turn %s on", device.name)
                    else Q __("would turn %s off", device.name)
                  else
                    if state then device.turnOn().then( => __("turned %s on", device.name) )
                    else device.turnOff().then( => __("turned %s off", device.name) )
                )
    return result

module.exports.ActionHandler = ActionHandler
module.exports.SwitchActionHandler = SwitchActionHandler
module.exports.LogActionHandler = LogActionHandler