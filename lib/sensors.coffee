# #Sensor
# A sensor can decide predicates. 
class Sensor extends require('events').EventEmitter
  type: 'unknwon'
  name: null

  getSensorValuesNames: ->
    throw new Error("your sensor must implement getSensorValuesNames")

  getSensorValue: (name) ->
    throw new Error("your sensor must implement getSensorValue")

  # This function should return true if the sensor can decide the given predicate.
  canDecide: (predicate) ->
    throw new Error("your sensor must implement canDecide")

  # The sensor should return `true` if the predicate is true and `false` if it is false.
  # If the sensor can not decide the predicate this function should throw an Error.
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


module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor