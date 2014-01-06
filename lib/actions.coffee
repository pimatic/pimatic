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

  runOnDeviceByNameOrId: (deviceName, doCallback) ->
    self = this
    assert typeof self.framework.devices is 'object'
    for id, device of self.framework.devices
      if id.toLowerCase() is deviceName or device.name.toLowerCase() is deviceName
        result = doCallback device
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
      deviceName = matches[1].trim()
      state = matches[2]
      state =  (if state is __("on") or state is "on" then on else off)
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