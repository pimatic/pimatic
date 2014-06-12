###
Devices
=======


###

cassert = require 'cassert'
assert = require 'assert'
Q = require 'q'
_ = require 'lodash'
t = require('decl-api').types

module.exports = (env) ->

  ###
  Device
  -----
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

      isValidType = (type) => type in _.values(t)
      assert isValidType(attr.type), "#{attrName} of #{@name} has no valid type."

      # If it is a Number it must have a unit
      if attr.type is t.number and not attr.unit? then attr.unit = ''
      # If it is a Boolean it must have labels
      if attr.type is t.boolean and not attr.labels then attr.labels = ["true", "false"]
      unless attr.label then attr.label = upperCaseFirst(attrName)

    constructor: ->
      assert @id?, "the device has no id"
      assert @name?, "the device has no name"
      assert @id.lenght isnt 0, "the id of the device is empty"
      assert @name.lenght isnt 0, "the name of the device is empty"
      @_checkAttributes()
      @_constructorCalled = yes
      @_attributesValues = {}
      for attrName of @attributes
        do (attrName) =>
          @on(attrName, (val) => @_attributesValues[attrName] = val )

    destroy: ->
      @removeAllListeners(attrName) for attrName of @attributes
      return

    # Checks if the actuator has a given action.
    hasAction: (name) -> @actions[name]?

    # Checks if the actuator has the attribute event.
    hasAttribute: (name) -> @attributes[name]?

    getLastAttributeValue: (attrName) ->
      return @_attributesValues[attrName]

    getAttributeValue: (attrName) ->
      getter = 'get' + upperCaseFirst(attrName)
      # call the getter
      result = @[getter]()
      # Be sure that it is a promise!
      assert Q.isPromise result, "#{getter} of #{@name} should always return a promise!"
      return result

    # Returns a template name to use in frontends.
    getTemplateName: -> "device"

    toJson: ->

      json = {
        id: @id
        name: @name
        template: @getTemplateName()
        attributes: []
        actions: []
      }

      for name, attr of @attributes
        attrJson = _.cloneDeep(attr)
        attrJson.name = name
        attrJson.value = @getLastAttributeValue(name)
        json.attributes.push attrJson
      
      for name, action of @actions
        actionJson = _.cloneDeep(action)
        actionJson.name = name
        json.actions.push actionJson

      return json

  ###
  Actuator
  -----
  An Actuator is an physical or logical element you can control by triggering an action on it.
  For example a power outlet, a light or door opener.
  ###
  class Actuator extends Device

    getTemplateName: -> "actuator"

  ###
  SwitchActuator
  -----
  A class for all devices you can switch on and off.
  ###
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
            type: t.boolean
      getState:
        description: "returns the current state of the switch"
        returns:
          state:
            type: t.boolean
        
    attributes:
      state:
        description: "the current state of the switch"
        type: t.boolean
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

  ###
  PowerSwitch
  ----------
  Just an alias for a SwitchActuator at the moment
  ###
  class PowerSwitch extends SwitchActuator

  ###
  DimmerActuator
  -------------
  Switch with additional dim functionality.
  ###
  class DimmerActuator extends SwitchActuator
    _dimlevel: null

    actions: 
      changeDimlevelTo:
        description: "sets the level of the dimmer"
        params:
          dimlevel:
            type: t.number
      changeStateTo:
        description: "changes the switch to on or off"
        params:
          state:
            type: t.boolean
      turnOn:
        description: "turns the dim level to 100%"
      turnOff:
        description: "turns the dim level to 0%"
        
    attributes:
      dimlevel:
        description: "the current dim level"
        type: t.number
        unit: "%"
      state:
        description: "the current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    # Returns a promise
    turnOn: -> @changeDimlevelTo 100

    # Retuns a promise
    turnOff: -> @changeDimlevelTo 0

    # Retuns a promise that is fulfilled when done.
    changeDimlevelTo: (state) ->
      throw new Error "Function \"changeDimlevelTo\" is not implemented!"

    _setDimlevel: (level) =>
      level = parseFloat(level)
      assert(not isNaN(level))
      cassert level >= 0
      cassert level <= 100
      if @_dimlevel is level then return
      @_dimlevel = level
      @emit "dimlevel", level
      @_setState(level > 0)

    # Returns a promise that will be fulfilled with the dim level
    getDimlevel: -> Q(@_dimlevel)

    getTemplateName: -> "dimmer"


  ###
  ShutterController
  -----
  A class for all devices you can switch on and off.
  ###
  class ShutterController extends Actuator
    _position: null

    attributes:
      position:
        label: "Position"
        description: "state of the shutter"
        type: t.string
        oneOf: ['up', 'down', 'stopped']

    actions: 
      moveUp:
        description: "raise the shutter"
      moveDown:
        description: "lower the shutter"
      stop:
        description: "stops the shutter move"
      moveToPosition:
        description: "changes the shutter state"
        params:
          state:
            type: t.string
        
    # Returns a promise
    moveUp: -> @moveToPosition('up')
    # Retuns a promise
    moveDown: -> @moveToPosition('down')

    stop: ->
      throw new Error "Function \"stop\" is not implemented!"

    # Retuns a promise that is fulfilled when done.
    moveToPosition: (position) ->
      throw new Error "Function \"moveToPosition\" is not implemented!"

    getTemplateName: -> "shutter"

    # Returns a promise that will be fulfilled with the position
    getPosition: -> Q(@_position)
    getTime: -> Q(@_time)

    _setPosition: (position) ->
      assert position in ['up', 'down', 'stopped']
      if @position is position then return
      @_position = position
      @emit "position", position

  ###
  Sensor
  ------
  ###
  class Sensor extends Device

    getTemplateName: -> "device"

  ###
  TemperatureSensor
  ------
  ###
  class TemperatureSensor extends Sensor

    attributes:
      temperature:
        description: "the messured temperature"
        type: t.number
        unit: '°C'

    getTemplateName: -> "temperature"

  ###
  PresenceSensor
  ------
  ###
  class PresenceSensor extends Sensor
    _presence: undefined

    attributes:
      presence:
        description: "presence of the human/device"
        type: t.boolean
        labels: ['present', 'absent']
        

    _setPresence: (value) ->
      if @_presence is value then return
      @_presence = value
      @emit 'presence', value


    getPresence: -> Q(@_presence)

    getTemplateName: -> "presence"

  ###
  ContactSensor
  ------
  ###
  class ContactSensor extends Sensor
    _contact: undefined

    attributes:
      contact:
        description: "state of the contact"
        type: t.boolean
        labels: ['closed', 'opened']

    _setContact: (value) ->
      if @_contact is value then return
      @_contact = value
      @emit 'contact', value

    getContact: -> Q(@_contact)

    getTemplateName: -> "contact"

  upperCaseFirst = (string) -> 
    unless string.length is 0
      string[0].toUpperCase() + string.slice(1)
    else ""

  return exports = {
    Device
    Actuator
    SwitchActuator
    PowerSwitch
    DimmerActuator
    ShutterController
    Sensor
    TemperatureSensor
    PresenceSensor
    ContactSensor
  }