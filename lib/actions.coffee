__ = require("i18n").__
Q = require 'q'
assert = require 'cassert'

class ActionHandler
  executeAction: (actionString, simulate) =>
    throw new Error("unimplemented")  

env = null

class SwitchActionHandler extends ActionHandler

  constructor: (_env, @framework) ->
    env = _env

  runOnActuatorByNameOrId: (actuatorName, doCallback) ->
    self = this
    assert typeof self.framework.actuators is 'object'
    for id, actuator of self.framework.actuators
      if id.toLowerCase() is actuatorName or actuator.name.toLowerCase() is actuatorName
        result = doCallback actuator
        #"break" when result was given by callback 
        if result? then return result

  executeAction: (actionString, simulate) =>
    self = this
    result = null
    regExpString = '^(?:turn)?(?:\\s+the)?(.+?)(on|off)$'
    matches = actionString.match (new RegExp regExpString)
    # Try the translated form:
    unless matches? then matches = actionString.match (new RegExp __(regExpString))
    if matches?
      actuatorName = matches[1].trim()
      state = matches[2]
      state =  (if state is __("on") or state is "on" then on else off)
      actionName = (if state then "turnOn" else "turnOff")
      result = self.runOnActuatorByNameOrId actuatorName, (actuator)->
        if actuator.hasAction actionName
          if simulate
            if state
              return Q.fcall -> __("would turn %s on", actuator.name)
            else 
              return Q.fcall -> __("would turn %s off", actuator.name)
          else
            if state
              return actuator.turnOn().then( ->
                __("turned %s on", actuator.name)
              )
            else 
              return actuator.turnOff().then( ->
                __("turned %s off", actuator.name)
              )
        else return null
    return result

class LogActionHandler extends ActionHandler

  constructor: (_env, @framework) ->
    env = _env

  executeAction: (actionString, simulate) =>
    regExpString = '^log\\s+"(.*)?"$'
    matches = actionString.match (new RegExp regExpString)
    if matches?
      stringToLog = matches[1]
      if simulate
        return Q.fcall -> __("would log \"%s\"", stringToLog)
      else
        return Q.fcall -> 
          env.logger.info stringToLog
          return null

module.exports.ActionHandler = ActionHandler
module.exports.SwitchActionHandler = SwitchActionHandler
module.exports.LogActionHandler = LogActionHandler