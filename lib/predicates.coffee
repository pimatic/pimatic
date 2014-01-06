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

class PresentPredicateProvider extends PredicateProvider
  _listener: {}

  constructor: (_env, @framework) ->
    env = _env

  canDecide: (predicate) ->
    info = @_parsePredicate predicate
    return if info? then 'state' else no 

  isTrue: (id, predicate) ->
    info = @_parsePredicate predicate
    if info? then return info.device.getSensorValue('present').then (present) =>
      return info.present is present
    else throw new Error "Sensor can not decide \"#{predicate}\"!"

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

      presentListener = (present) =>
        callback(info.present is present)

      device.on 'present', presentListener

      @_listener[id] =
        id: id
        present: info.present
        destroy: => device.removeListener 'present', presentListener

    else throw new Error "PresentPredicateProvider can not decide \"#{predicate}\"!"


  _parsePredicate: (predicate) ->
    regExpString = '^(.+)\\s+is\\s+(not\\s+)?present$'
    matches = predicate.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      for id, d of @framework.devices
        if deviceName is d.name or deviceName is d.id
          return info =
            device: d
            present: (if matches[2]? then no else yes) 
    return null


module.exports.PredicateProvider = PredicateProvider
module.exports.PresentPredicateProvider = PresentPredicateProvider