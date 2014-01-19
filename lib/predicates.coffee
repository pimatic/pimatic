__ = require("i18n").__
Q = require 'q'
assert = require 'cassert'

class PredicateProvider
  # This function should return 'event' or 'state' if the sensor can decide the given predicate.
  # If the sensor can decide the predicate and it is a one shot event like 'its 10pm' then the
  # canDecide should return `'event'`
  # If the sensor can decide the predicate and it can be true or false like 'x is present' then 
  # canDecide should return `'state'`
  # If the sensor can not decide the given predicate then canDecide should return `false`
  canDecide: (predicate) ->
    throw new Error("your sensor must implement canDecide")

  # The sensor should return `true` if the predicate is true and `false` if it is false.
  # If the sensor can not decide the predicate or the predicate is an eventthis function 
  # should throw an Error.
  isTrue: (id, predicate) ->
    throw new Error("your sensor must implement itTrue")

  # The sensor should call the callback if the state of the predicate changes (it becomes true or 
  # false).
  # If the sensor can not decide the predicate this function should throw an Error.
  notifyWhen: (id, predicate, callback) ->
    throw new Error("your sensor must implement notifyWhen")

  # Cancels the notification for the predicate with the id given id.
  cancelNotify: (id) ->
    throw new Error("your sensor must implement cancelNotify")

env = null

class DeviceEventPredicateProvider extends PredicateProvider
  _listener: {}

  canDecide: (predicate) ->
    info = @_parsePredicate predicate
    return if info? then 'state' else no 

  isTrue: (id, predicate) ->
    info = @_parsePredicate predicate
    if info? then return info.getPredicateValue()
    else throw new Error "Can not decide \"#{predicate}\"!"

  # Removes the notification for an with `notifyWhen` registered predicate. 
  cancelNotify: (id) ->
    listener = @_listener[id]
    if listener?
      listener.destroy()
      delete @_listener[id]

  # Registers notification. 
  notifyWhen: (id, predicate, callback) ->
    info = @_parsePredicate predicate
    if info?
      device = info.device
      event = info.event
      eventListener = info.getEventListener(callback)

      device.on event, eventListener

      @_listener[id] =
        id: id
        destroy: => device.removeListener event, eventListener

    else throw new Error "DeviceEventPredicateProvider can not decide \"#{predicate}\"!"

  _parsePredicate: (predicate) ->
    throw new Error 'Should be implemented by supper class.'


class PresencePredicateProvider extends DeviceEventPredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  _parsePredicate: (predicate) ->
    predicate = predicate.toLowerCase()
    regExpString = '^(.+)\\s+is\\s+(not\\s+present|present|absent)$'
    matches = predicate.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      negated = (if matches[2] isnt "present" then yes else no) 
      for id, d of @framework.devices
        if d.hasAttribute 'presence'
          if d.matchesIdOrName deviceName
            return info =
              device: d
              event: 'presence'
              getPredicateValue: => 
                d.getAttributeValue('presence').then (presence) =>
                  if negated then not presence else presence
              getEventListener: (callback) => 
                return eventListener = (presence) => 
                  callback(if negated then not presence else presence)
              negated: negated # for testing only
    return null

class SwitchPredicateProvider extends DeviceEventPredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  _parsePredicate: (predicate) ->
    predicate = predicate.toLowerCase()
    regExpString = '^(.+)\\s+is\\s+(?:turned\\s+)?(on|off)$'
    matches = predicate.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      state = matches[2] is "on"
      for id, d of @framework.devices
        if d.hasAttribute 'state'
          if d.matchesIdOrName deviceName
            return info =
              device: d
              event: 'state'
              getPredicateValue: => 
                d.getAttributeValue('state').then (s) => s is state
              getEventListener: (callback) => 
                return eventListener = (s) => callback(s is state)
              state: state # for testing only
    return null

class DeviceAttributePredicateProvider extends DeviceEventPredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  _compareValues: (comparator, value, referenceValue) ->
    unless isNaN value
      value = parseFloat value
    return switch comparator
      when '==' then value is referenceValue
      when '!=' then value isnt referenceValue
      when '<' then value < referenceValue
      when '>' then value > referenceValue
      else throw new Error "Unknown comparator: #{comparator}"


  _parsePredicate: (predicate) ->
    predicate = predicate.toLowerCase()
    regExpString = 
      '^(.+)\\s+' + # the attribute
      'of\\s+' + # of
      '(.+?)\\s+' + # the device
      '(?:is\\s+)?' + # is
      '(equal\\s+to|equals*|lower|less|greater|is not|is)' + 
        # is, is not, equal, equals, lower, less, greater
      '(?:|\\s+equal|\\s+than|\\s+as)?\\s+' + # equal to, equal, than, as
      '(.+)' # reference value
    matches = predicate.match (new RegExp regExpString)
    if matches?
      attributeName = matches[1].trim().toLowerCase()
      deviceName = matches[2].trim().toLowerCase()
      comparator = matches[3].trim() 
      referenceValue = matches[4].trim()
      #console.log "#{attributeName}, #{deviceName}, #{comparator}, #{referenceValue}"
      for id, d of @framework.devices
        if d.matchesIdOrName deviceName
          if d.hasAttribute attributeName
            comparator = switch comparator
              when 'is', 'equal', 'equals', 'equal to', 'equals to' then '=='
              when 'is not' then '!='
              when 'greater' then '>'
              when 'lower', 'less' then '<'
              else 
                env.logger.error "Illegal comparator \"#{comparator}\""
                false

            unless comparator is false
              # if the attribute has a unit
              unit = d.attributes[attributeName].unit
              if unit?
                unit = unit.toLowerCase()
                # then remove it from the reference value and
                # allow just "c" for "°C"
                lastIndex = referenceValue.replace('°c', 'c').lastIndexOf unit.replace('°c', 'c')
                if lastIndex isnt -1
                  referenceValue = referenceValue.substring 0, lastIndex

              # If the attribute is numerical
              if d.attributes[attributeName].type is Number
                # then check the referenceValue
                if isNaN(referenceValue)
                  throw new Error "Expected #{referenceValue} in \"#{predicate}\" to be a number."
                # and convert it to a float.
                referenceValue = parseFloat referenceValue
              else
                # if its not numerical but comparator is less or greater
                if comparator in ["<", ">"]
                  # then something gone wrong.
                  throw new Error "Can not compare a non numerical attribute with less or creater."

              lastValue = null
              return info =
                device: d
                event: attributeName
                getPredicateValue: => 
                  d.getAttributeValue(attributeName).then (value) =>
                    @_compareValues comparator, value, referenceValue
                getEventListener: (callback) => 
                  return attributeListener = (value) =>
                    state = @_compareValues comparator, value, referenceValue
                    if state isnt lastValue
                      lastValue = state
                      callback state
                comparator: comparator # for testing only
                attributeName: attributeName # for testing only
                referenceValue: referenceValue
    return null


module.exports.PredicateProvider = PredicateProvider
module.exports.PresencePredicateProvider = PresencePredicateProvider
module.exports.SwitchPredicateProvider = SwitchPredicateProvider
module.exports.DeviceAttributePredicateProvider = DeviceAttributePredicateProvider