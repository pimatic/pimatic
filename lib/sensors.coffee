class Sensor
  type: 'unknwon'
  name: null

  getSensorValuesNames: ->
    throw new Error("your sensor must implement getSensorValuesNames")

  getSensorValue: (name) ->
    throw new Error("your sensor must implement getSensorValue")

  isTrue: (id, predicate) ->
    throw new Error("your sensor must implement itTrue")

  notifyWhen: (id, predicate, callback) ->
    throw new Error("your sensor must implement notifyWhen")

  cancelNotify: (id) ->
    throw new Error("your sensor must implement cancelNotify")

class TemperatureSensor extends Sensor
  type: 'TemperatureSensor'


module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor