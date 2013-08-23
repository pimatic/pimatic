module.exports = (server) ->

  class DefaultRules
    executeAction: (actionString, simulate, callback) =>
      result = null
      actionString = actionString.toLowerCase()
      #console.log actionString
      matches = actionString.match /^(?:turn)?(?:\s+the)?(.+?)(on|off)$/
      #console.log matches
      if matches?
        actuatorName = matches[1].trim()
        state = matches[2]
        actionName = (if state is "on" then "turnOn" else "turnOff")
        result = @runOnActuatorByNameOrId  actuatorName, (actuator)->
          if actuator.hasAction actionName
                if simulate
                  return ->
                    callback(null, "would turn #{actuator.name} #{state}")
                else
                  if state is "on"
                    return  ->
                      actuator.turnOn (e) ->
                        callback(e, "turned #{actuator.name} on")
                  else 
                    return ->
                      actuator.turnOff (e) ->
                        callback(e, "turned #{actuator.name} off")
          else return null
      return result

    runOnActuatorByNameOrId: (actuatorName, doCallback) ->
      for id of server.actuators
        actuator = server.actuators[id]
        if id.toLowerCase() is actuatorName or actuator.name.toLowerCase() is actuatorName
          console.log "actuator found #{actuator.id}"
          result = doCallback actuator
          #"break" when reult was given by callback 
          if result? then return result

  return new DefaultRules






