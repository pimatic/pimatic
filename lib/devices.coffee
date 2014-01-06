# Povides the `Actuator` class and some basic common subclasses for the Backend modules. 
# 
assert = require 'cassert'
Q = require 'q'


class Device extends require('events').EventEmitter

# An Actuator is an physical or logical element you can control by triggering an action on it.
# For example a power outlet, a light or door opener.
class Actuator extends Device
  # Defines the actions an Actuator has.
  actions: []
  # A unic id defined by the config or by the backend module that provies the actuator.
  id: null
  # The name of the actuator to display at the frontend.
  name: null
  # Events of the actuator.
  events: []

  # Checks if the actuator has a given action.
  hasAction: (name) ->
    name in @actions

  # Checks if the actuator has the given event.
  hasEvent: (name) ->
    name in @events

# A class for all you can switch on and off.
class SwitchActuator extends Actuator
  type: 'SwitchActuator'
  _state: null
  actions: ["turnOn", "turnOff", "changeStateTo", "getState"]
  events: ["state"]

  # Returns a promise
  turnOn: ->
    @changeStateTo on

  # Retuns a promise
  turnOff: ->
    @changeStateTo off

  # Retuns a promise
  changeStateTo: (state) ->
    throw new Error "Function \"changeStateTo\" is not implemented!"

  getState: ->
    self = this
    return Q.fcall -> self._state

  _setState: (state) ->
    self = this
    self._state = state
    self.emit "state", state

class PowerSwitch extends SwitchActuator


# #Sensor
class Sensor extends Device
  type: 'unknwon'
  name: null

  getSensorValuesNames: ->
    throw new Error("your sensor must implement getSensorValuesNames")

  getSensorValue: (name) ->
    throw new Error("your sensor must implement getSensorValue")


class TemperatureSensor extends Sensor
  type: 'TemperatureSensor'

class PresentsSensor extends Sensor
  type: 'PresentsSensor'
  _present: undefined

  getSensorValuesNames: -> ["present"]

  getSensorValue: (name) ->
    switch name
      when "present" then return Q.fcall => @_present
      else throw new Error "Illegal sensor value name"

  _setPresent: (value) ->
    if @_present is value then return
    @_present = value
    #@_notifyListener()
    @emit 'present', value


module.exports.Device = Device
module.exports.Actuator = Actuator
module.exports.SwitchActuator = SwitchActuator
module.exports.PowerSwitch = PowerSwitch
module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor
module.exports.PresentsSensor = PresentsSensor