__ = require("i18n").__

module.exports = (server) ->

  class DefaultRules
    executeAction: (actionString, simulate, callback) =>
      result = null
      actionString = actionString.toLowerCase()
      #console.log actionString
      regExpString = '^(?:turn)?(?:\\s+the)?(.+?)(on|off)$'
      matches = actionString.match (new RegExp regExpString)
      # Try the translated form:
      unless matches? then matches = actionString.match (new RegExp __(regExpString))
      if matches?
        actuatorName = matches[1].trim()
        state = matches[2]
        state =  (if state is __("on") then on else off)
        actionName = (if state then "turnOn" else "turnOff")
        result = @runOnActuatorByNameOrId  actuatorName, (actuator)->
          if actuator.hasAction actionName
                if simulate
                  if state
                    return ->
                      callback null, __("would turn %s on", actuator.name)
                  else 
                    return ->
                      callback null, __("would turn %s off", actuator.name)
                else
                  if state
                    return ->
                      actuator.turnOn (e) ->
                        callback e, __("turned %s on", actuator.name)
                  else 
                    return ->
                      actuator.turnOff (e) ->
                        callback e, __("turned %s off", actuator.name)
          else return null
      return result

    runOnActuatorByNameOrId: (actuatorName, doCallback) ->
      for id of server.actuators
        actuator = server.actuators[id]
        if id.toLowerCase() is actuatorName or actuator.name.toLowerCase() is actuatorName
          result = doCallback actuator
          #"break" when reult was given by callback 
          if result? then return result

  return new DefaultRules






