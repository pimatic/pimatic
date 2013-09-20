__ = require("i18n").__
logger = require "./logger"

module.exports = (server) ->

  class DefaultRules
    executers = null

    constructor: ->
      @executers = [] 
      @executers.push @executeLogAction
      @executers.push @executeSwitchAction

    executeAction: (actionString, simulate, callback) =>
      result = null
      actionString = actionString.toLowerCase()
      for executer in @executers
        result = executer actionString, simulate, callback
        if result? then break
      return result

    executeSwitchAction: (actionString, simulate, callback) =>
      result = null
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
                return returnedCallback = ->
                  callback null, __("would turn %s on", actuator.name)
              else 
                return returnedCallback = ->
                  callback null, __("would turn %s off", actuator.name)
            else
              if state
                return returnedCallback = ->
                  actuator.turnOn (e) ->
                    callback e, __("turned %s on", actuator.name)
              else 
                return returnedCallback = ->
                  actuator.turnOff (e) ->
                    callback e, __("turned %s off", actuator.name)
          else return null
      return result

    executeLogAction: (actionString, simulate, callback) =>
      regExpString = '^log\\s+"(.*)?\"$'
      matches = actionString.match (new RegExp regExpString)
      if matches?
        stringToLog = matches[1]
        if simulate
          return returnedCallback = ->
            callback null, __("would log \"%s\"", stringToLog)
        else
          return returnedCallback = ->
            logger.log stringToLog
            callback null, __("log: \"%s\"", stringToLog)

    runOnActuatorByNameOrId: (actuatorName, doCallback) ->
      for id of server.actuators
        actuator = server.actuators[id]
        if id.toLowerCase() is actuatorName or actuator.name.toLowerCase() is actuatorName
          result = doCallback actuator
          #"break" when reult was given by callback 
          if result? then return result

  return new DefaultRules






