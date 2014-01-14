# Povides the `Actuator` class and some basic common subclasses for the Backend modules. 
# 
assert = require 'cassert'
Q = require 'q'
_ = require 'lodash'

# #Device class
# The Deive class is the common Superclass for all Devices like Actuators or Sensors
class Device extends require('events').EventEmitter
  # A unic id defined by the config or by the plugin that provies the device.
  id: null
  # The name of the actuator to display at the frontend.
  name: null

  # Defines the actions an device has.
  actions: {}
  # Events the device emits.
  properties: {}

  # Checks if the actuator has a given action.
  hasAction: (name) -> @actions[name]?

  # Checks if the actuator has the property event.
  hasProperty: (name) -> @properties[name]?

  getProperty: (property) ->
    getter = 'get' + property[0].toUpperCase() + property.slice(1)
    return @[getter]()

  # Checks if find matches the id or name in lower case.
  matchesIdOrName: (find) ->
    find = find.toLowerCase()
    return find is @id.toLowerCase() or find is @name.toLowerCase()

  # Returns a template name to use in frontends.
  getTemplateName: -> "device"

# An Actuator is an physical or logical element you can control by triggering an action on it.
# For example a power outlet, a light or door opener.
class Actuator extends Device

  getTemplateName: -> "actuator"

# A class for all you can switch on and off.
class SwitchActuator extends Actuator
  _state: null
  actions: 
    turnOn:
      description: "turns the switch on"
    turnOff:
      description: "turns the switch off"
    changeStateTo:
      description: "changes the siwitch to on or off"
      params:
        state:
          type: Boolean
    getState:
      description: "returns the current state of the switch"
      returns:
        state:
          type: Boolean
      
  properties:
    state:
      desciption: "the current state of the switch"
      type: Boolean
    labels: ['on', 'off']

  # Returns a promise
  turnOn: ->
    @changeStateTo on

  # Retuns a promise
  turnOff: ->
    @changeStateTo off

  # Retuns a promise that is fulfilled when done.
  changeStateTo: (state) ->
    throw new Error "Function \"changeStateTo\" is not implemented!"

  # Returns a promise that will be fulfilled with the state
  getState: ->
    self = this
    return Q.fcall -> self._state

  _setState: (state) ->
    self = this
    self._state = state
    self.emit "state", state

  getTemplateName: -> "switch"

class PowerSwitch extends SwitchActuator

# #Sensor
class Sensor extends Device

  getTemplateName: -> "sensor"


class TemperatureSensor extends Sensor

  properties:
    temperature:
      desciption: "the messured temperature"
      type: Number
      unit: '°C'

  getTemplateName: -> "temperature"

class PresenceSensor extends Sensor
  _presence: undefined

  properties:
    presence:
      desciption: "is the human/device present"
      type: Boolean
      labels: ['present', 'absent']
      

  _setPresence: (value) ->
    if @_presence is value then return
    @_presence = value
    #@_notifyListener()
    @emit 'presence', value

  getTemplateName: -> "presence"


module.exports.Device = Device
module.exports.Actuator = Actuator
module.exports.SwitchActuator = SwitchActuator
module.exports.PowerSwitch = PowerSwitch
module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor
module.exports.PresenceSensor = PresenceSensor