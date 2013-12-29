#
Q = require 'q'

# #Sensor
# A sensor can decide predicates. 
class Sensor extends require('events').EventEmitter
  type: 'unknwon'
  name: null

  getSensorValuesNames: ->
    throw new Error("your sensor must implement getSensorValuesNames")

  getSensorValue: (name) ->
    throw new Error("your sensor must implement getSensorValue")

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

class TemperatureSensor extends Sensor
  type: 'TemperatureSensor'

class PresentsSensor extends Sensor
  type: 'PresentsSensor'
  _present: undefined
  _listener: {}

  getSensorValuesNames: -> ["present"]

  getSensorValue: (name) ->
    switch name
      when "present" then return Q.fcall => @_present
      else throw new Error "Illegal sensor value name"

  canDecide: (predicate) ->
    info = @_parsePredicate predicate
    return if info? then 'state' else no 

  isTrue: (id, predicate) ->
    info = @_parsePredicate predicate
    if info? then return Q.fcall => info.present is @_present
    else throw new Error "Sensor can not decide \"#{predicate}\"!"

  # Removes the notification for an with `notifyWhen` registered predicate. 
  cancelNotify: (id) ->
    if @_listener[id]?
      delete @_listener[id]

  # Registers notification. 
  notifyWhen: (id, predicate, callback) ->
    info = @_parsePredicate predicate
    if info?
      @_listener[id] =
        id: id
        callback: callback
        present: info.present
    else throw new Error "PingPresents sensor can not decide \"#{predicate}\"!"

  _setPresent: (value) ->
    if @_present is value then return
    @_present = value
    @_notifyListener()
    @emit 'present', value

  _notifyListener: ->
    for id, l of @_listener
      l.callback(l.present is @_present)


  _parsePredicate: (predicate) ->
    regExpString = '^(.+)\\s+is\\s+(not\\s+)?present$'
    matches = predicate.match (new RegExp regExpString)
    if matches?
      deviceName = matches[1].trim()
      if deviceName is @name or deviceName is @id
        return info =
          deviceId: @id
          present: (if matches[2]? then no else yes) 
    return null


module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor
module.exports.PresentsSensor = PresentsSensor