###
Devices
=======


###

cassert = require 'cassert'
assert = require 'assert'
Q = require 'q'
_ = require 'lodash'

##A Device
###
The Device class is the common superclass for all devices like actuators or sensors. 
###
class Device extends require('events').EventEmitter
  # A unic id defined by the config or by the plugin that provies the device.
  id: null
  # The name of the actuator to display at the frontend.
  name: null

  # Defines the actions an device has.
  actions: {}
  # attributes the device has. For examples see devices below. 
  attributes: {}

  _checkAttributes: ->
    for attr of @attributes 
      @_checkAttribute attr

  _checkAttribute: (attrName) ->
    attr = @attributes[attrName]
    assert attr.description?, "no description for #{attrName} of #{@name} given"
    assert attr.type?, "no type for #{attrName} of #{@name} given"
    validTypes = [Boolean, String, Number, Date]
    isValidType = (t) => _.any(validTypes, (t) -> attr.type is t) or Array.isArray attr.type
    assert isValidType(attr.type), "#{attrName} of #{@name} has no valid type."
    
    # If it is a Number it must have a unit
    if attr.type is Number and not attr.unit? then attr.unit = ''
    # If it is a Boolean it must have labels
    if attr.type is Boolean and not attr.labels then attr.labels = ["true", "false"]
    unless attr.label then attr.label = upperCaseFirst(attrName)

  constructor: ->
    assert @id?, "the device has no id"
    assert @name?, "the device has no name"
    assert @id.lenght isnt 0, "the id of the device is empty"
    assert @name.lenght isnt 0, "the name of the device is empty"
    @_checkAttributes()
    @_constructorCalled = yes

  # Checks if the actuator has a given action.
  hasAction: (name) -> @actions[name]?

  # Checks if the actuator has the attribute event.
  hasAttribute: (name) -> @attributes[name]?

  getAttributeValue: (attribute) ->
    getter = 'get' + upperCaseFirst(attribute)
    # call the getter
    result = @[getter]()
    # Be sure that it is a promise!
    assert Q.isPromise result, "#{getter} of #{@name} should always return a promise!"
    return result

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
      description: "changes the switch to on or off"
      params:
        state:
          type: Boolean
    getState:
      description: "returns the current state of the switch"
      returns:
        state:
          type: Boolean
      
  attributes:
    state:
      description: "the current state of the switch"
      type: Boolean
      labels: ['on', 'off']

  # Returns a promise
  turnOn: -> @changeStateTo on

  # Retuns a promise
  turnOff: -> @changeStateTo off

  # Retuns a promise that is fulfilled when done.
  changeStateTo: (state) ->
    throw new Error "Function \"changeStateTo\" is not implemented!"

  # Returns a promise that will be fulfilled with the state
  getState: -> Q(@_state)

  _setState: (state) ->
    if @_state is state then return
    @_state = state
    @emit "state", state

  getTemplateName: -> "switch"


class DimmerActuator extends SwitchActuator
  _dimlevel: null

  actions: 
    changeDimlevelTo:
      description: "sets the level of the dimmer"
      params:
        dimlevel:
          type: Number
    changeStateTo:
      description: "changes the switch to on or off"
      params:
        state:
          type: Boolean
    turnOn:
      description: "turns the dim level to 100%"
    turnOff:
      description: "turns the dim level to 0%"
      
  attributes:
    dimlevel:
      description: "the current dim level"
      type: Number
      unit: "%"
    state:
      description: "the current state of the switch"
      type: Boolean
      labels: ['on', 'off']

  # Returns a promise
  turnOn: -> @changeDimlevelTo 100

  # Retuns a promise
  turnOff: -> @changeDimlevelTo 0

  # Retuns a promise that is fulfilled when done.
  changeDimlevelTo: (state) ->
    throw new Error "Function \"changeDimlevelTo\" is not implemented!"

  _setDimlevel: (level) =>
    assert not isNaN(level) 
    level = parseFloat(level)
    cassert level >= 0
    cassert level <= 100
    if @_dimlevel is level then return
    @_dimlevel = level
    @emit "dimlevel", level
    @_setState(level > 0)

  # Returns a promise that will be fulfilled with the dim level
  getDimlevel: -> Q(@_dimlevel)

  getTemplateName: -> "dimmer"

class PowerSwitch extends SwitchActuator

# #Sensor
class Sensor extends Device

  getTemplateName: -> "device"


class TemperatureSensor extends Sensor

  attributes:
    temperature:
      description: "the messured temperature"
      type: Number
      unit: '°C'

  getTemplateName: -> "temperature"

class PresenceSensor extends Sensor
  _presence: undefined

  attributes:
    presence:
      description: "presence of the human/device"
      type: Boolean
      labels: ['present', 'absent']
      

  _setPresence: (value) ->
    if @_presence is value then return
    @_presence = value
    @emit 'presence', value


  getPresence: -> Q(@_presence)

  getTemplateName: -> "presence"

upperCaseFirst = (string) -> 
  unless string.length is 0
    string[0].toUpperCase() + string.slice(1)
  else ""


module.exports.Device = Device
module.exports.Actuator = Actuator
module.exports.SwitchActuator = SwitchActuator
module.exports.PowerSwitch = PowerSwitch
module.exports.DimmerActuator = DimmerActuator
module.exports.Sensor = Sensor
module.exports.TemperatureSensor = TemperatureSensor
module.exports.PresenceSensor = PresenceSensor