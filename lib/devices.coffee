###
Devices
=======


###

cassert = require 'cassert'
assert = require 'assert'
Promise = require 'bluebird'
_ = require 'lodash'
t = require('decl-api').types
declapi = require 'decl-api'
events = require 'events'

module.exports = (env) ->

  ###
  Device
  -----
  The Device class is the common superclass for all devices like actuators or sensors.
  ###
  class Device extends require('events').EventEmitter
    # A unique id defined by the config or by the plugin that provides the device.
    id: null
    # The name of the actuator to display at the frontend.
    name: null

    # Defines the actions an device has.
    actions: {}
    # attributes the device has. For examples see devices below.
    attributes: {}

    template: "device"

    config: {}

    _checkAttributes: ->
      for attr of @attributes
        @_checkAttribute attr

    _checkAttribute: (attrName) ->
      attr = @attributes[attrName]
      assert attr.description?, "No description for #{attrName} of #{@name} given"
      assert attr.type?, "No type for #{attrName} of #{@name} given"

      isValidType = (type) => type in _.values(t)
      assert isValidType(attr.type), "#{attrName} of #{@name} has no valid type."

      # If it is a Number it must have a unit
      if attr.type is t.number and not attr.unit? then attr.unit = ''
      # If it is a Boolean it must have labels
      if attr.type is t.boolean and not attr.labels then attr.labels = ["true", "false"]
      unless attr.label then attr.label = upperCaseFirst(attrName)
      unless attr.discrete?
        attr.discrete = (if attr.type is "number" then no else yes)

    constructor: ->
      assert @id?, "The device has no ID"
      assert @name?, "The device has no name"
      assert @id.length isnt 0, "The ID of the device is empty"
      assert @name.length isnt 0, "The name of the device is empty"
      @_checkAttributes()
      @_constructorCalled = yes
      @_attributesMeta = {}
      @_initAttributeMeta(attrName, attr) for attrName, attr of @attributes
      super()


    _initAttributeMeta: (attrName, attr) ->
      device = @
      @_attributesMeta[attrName] = {
        value: null
        error: null
        history: []
        update: (value) ->
          if attr.type in ["number", "integer"] and typeof value is "string"
            env.logger.error(
              "Got string value for attribute #{attrName} of #{device.constructor.name} but " +
              "attribute type is #{attr.type}."
            )
          timestamp = (new Date()).getTime()
          @value = value
          @lastUpdate = timestamp
          if @history.length is 30
            @history.shift()
          @history.push {t:timestamp, v:value}
      }
      attrListener = (value) => @_attributesMeta[attrName].update(value)
      @_attributesMeta[attrName].attrListener = attrListener
      @on(attrName, attrListener)

    destroy: ->
      @emit('destroy', @)
      @removeAllListeners('destroy')
      @removeAllListeners(attrName) for attrName of @attributes
      @_destroyed = true
      return

    afterRegister: ->
      for attrName of @attributes
        do (attrName) =>
          # force update of the device value
          meta = @_attributesMeta[attrName]
          unless meta.value?
            @getUpdatedAttributeValue(attrName).then( (value) =>
              if (not meta.lastUpdate?) or (new Date().getTime() - meta.lastUpdate)
                @emit(attrName, value)
            ).catch( (err) =>
              @logAttributeError(attrName, err)
            ).done()

    # Checks if the actuator has a given action.
    hasAction: (name) -> @actions[name]?

    # Checks if the actuator has the attribute event.
    hasAttribute: (name) -> @attributes[name]?

    getLastAttributeValue: (attrName) ->
      return @_attributesMeta[attrName].value

    addAttribute: (name, attribute) ->
      assert (not @_constructorCalled), "Attributes can only be added in the constructor"
      if @attributes is @constructor.prototype.attributes
        @attributes = _.clone(@attributes)
      @attributes[name] = attribute

    addAction: (name, action) ->
      assert (not @_constructorCalled), "Actions can only be added in the constructor"
      if @actions is @constructor.prototype.actions
        @actions = _.clone(@actions)
      @actions[name] = action

    updateName: (name) ->
      if name is @name then return
      @name = name
      @emit "nameChanged", this

    getUpdatedAttributeValue: (attrName, arg) ->
      getter = 'get' + upperCaseFirst(attrName)
      # call the getter
      assert @[getter]?, "Method #{getter} of #{@name} does not exist!"
      result = Promise.resolve().then( => return @[getter](arg) )
      return result

    getUpdatedAttributeValueCached: (attrName, arg) ->
      unless @_promiseCache then @_promiseCache = {}
      if @_promiseCache[attrName]? then return @_promiseCache[attrName]
      @_promiseCache[attrName] = @getUpdatedAttributeValue(attrName, arg).then( (value) =>
        delete @_promiseCache[attrName]
        return value
      , (error) =>
        delete @_promiseCache[attrName]
        throw error
      )
      return @_promiseCache[attrName]

    _createGetter: (attributeName, fn) ->
      getterName = 'get' + attributeName[0].toUpperCase() + attributeName.slice(1)
      @[getterName] = fn
      return

    toJson: ->
      json = {
        id: @id
        name: @name
        template: @template
        attributes: []
        actions: []
        config: @config
        configDefaults: @config.__proto__
      }

      for name, attr of @attributes
        meta = @_attributesMeta[name]
        attrJson = _.cloneDeep(attr)
        attrJson.name = name
        attrJson.value = meta.value
        attrJson.history = meta.history
        attrJson.lastUpdate = meta.lastUpdate
        json.attributes.push attrJson

      for name, action of @actions
        actionJson = _.cloneDeep(action)
        actionJson.name = name
        json.actions.push actionJson

      # experimental feature to list the capabilities of a device
      predicate = (accumulator, value) =>
        if (@ instanceof value) and (@constructor.name isnt value.name)
          accumulator.push value.name
        return accumulator
      json.capabilities = [
        ErrorDevice
        Actuator
        SwitchActuator
        PowerSwitch
        DimmerActuator
        ShutterController
        Sensor
        TemperatureSensor
        PresenceSensor
        ContactSensor
        HeatingThermostat
        ButtonsDevice
        InputDevice
        VariablesDevice
        VariableInputDevice
        VariableTimeInputDevice
        AVPlayer
        Timer
      ].reduce predicate, []
      return json

    _setupPolling: (attrName, interval, additionalCallback) ->
      cb = additionalCallback ? Promise.resolve
      unless typeof interval is 'number'
        throw new Error("Illegal polling interval #{interval}!")
      unless interval > 0
        throw new Error("Polling interval must be greater then 0, was #{interval}")
      doPolling = () =>
        if @_destroyed then return
        Promise.resolve()
          .then( =>
            cb()
          )
          .then( =>
            @getUpdatedAttributeValue(attrName)
          )
          .then( (value) =>
            # may emit value, if it was not already emitted by getter
            lastUpdate = @_attributesMeta[attrName].lastUpdate
            if lastUpdate? and (new Date().getTime() - lastUpdate) < 500
              return
            @emit(attrName, value)
          )
          .catch( (err) =>
            @logAttributeError(attrName, err) )
          .finally( =>
            if @_destroyed then return
            setTimeout(doPolling, interval)
          ).done()
      setTimeout(doPolling, interval)

    logAttributeError: (attrName, err) ->
      lastError = @_attributesMeta[attrName].error
      if lastError? and err.message is lastError.message
        @logger.debug("Suppressing repeated error for #{@id}.#{attrName} #{err.message}")
        @logger.debug(err.stack)
        return
      # save attribute error
      @_attributesMeta[attrName].error = err
      # clear error on next success
      @once(attrName, => @_attributesMeta[attrName].error = null )
      @logger.error("Error getting attribute value #{@id}.#{attrName}: #{err.message}")
      @logger.debug(err.stack)

  ###
  ErrorDevice
  -----
  Devices of this type are created if the create operation
  for the real type cant be created
  ###
  class ErrorDevice extends Device

    constructor: (@config, @error) ->
      @name = @config.name
      @id = @config.id
      super()

    destroy: () ->
      super()

  ###
  Actuator
  -----
  An Actuator is an physical or logical element you can control by triggering an action on it.
  For example a power outlet, a light or door opener.
  ###
  class Actuator extends Device

  ###
  SwitchActuator
  -----
  A class for all devices you can switch on and off.
  ###
  class SwitchActuator extends Actuator
    _state: null

    actions:
      turnOn:
        description: "Turns the switch on"
      turnOff:
        description: "Turns the switch off"
      changeStateTo:
        description: "Changes the switch to on or off"
        params:
          state:
            type: t.boolean
      toggle:
        description: "Toggle the state of the switch"
      getState:
        description: "Returns the current state of the switch"
        returns:
          state:
            type: t.boolean

    attributes:
      state:
        description: "The current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    template: "switch"

    # Returns a promise
    turnOn: -> @changeStateTo on

    # Returns a promise
    turnOff: -> @changeStateTo off

    toggle: ->
      @getState().then( (state) => @changeStateTo(!state) )

    # Returns a promise that is fulfilled when done.
    changeStateTo: (state) ->
      throw new Error "Function \"changeStateTo\" is not implemented!"

    # Returns a promise that will be fulfilled with the state
    getState: -> Promise.resolve(@_state)

    _setState: (state) ->
      if @_state is state then return
      @_state = state
      @emit "state", state

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
        description: "Sets the level of the dimmer"
        params:
          dimlevel:
            type: t.number
      changeStateTo:
        description: "Changes the switch to on or off"
        params:
          state:
            type: t.boolean
      turnOn:
        description: "Turns the dim level to 100%"
      turnOff:
        description: "Turns the dim level to 0%"
      toggle:
        description: "Toggle the state of the dimmer"

    attributes:
      dimlevel:
        description: "The current dim level"
        type: t.number
        unit: "%"
      state:
        description: "The current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    template: "dimmer"

    # Returns a promise
    turnOn: -> @changeDimlevelTo 100

    # Returns a promise
    turnOff: -> @changeDimlevelTo 0

    # Returns a promise that is fulfilled when done.
    changeDimlevelTo: (state) ->
      throw new Error "Function \"changeDimlevelTo\" is not implemented!"

    # Returns a promise that is fulfilled when done.
    changeStateTo: (state) ->
      return if state then @turnOn() else @turnOff()

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
    getDimlevel: -> Promise.resolve(@_dimlevel)


  ###
  ShutterController
  -----
  A class for all devices you can move up and down.
  ###
  class ShutterController extends Actuator
    _position: null

    # Approx. amount of time (in seconds) for shutter to close or open completely.
    rollingTime = null

    attributes:
      position:
        label: "Position"
        description: "State of the shutter"
        type: t.string
        enum: ['up', 'down', 'stopped']
        labels: { up: 'up', down: 'down', stopped: 'stopped'}

    actions:
      moveUp:
        description: "Raise the shutter"
      moveDown:
        description: "Lower the shutter"
      stop:
        description: "Stops the shutter move"
      moveToPosition:
        description: "Changes the shutter state"
        params:
          state:
            type: t.string
      moveByPercentage:
        description: "Move shutter by percentage relative to current position"
        params:
          percentage:
            type: t.number

    template: "shutter"

    # Returns a promise
    moveUp: -> @moveToPosition('up')
    # Returns a promise
    moveDown: -> @moveToPosition('down')

    stop: ->
      throw new Error "Function \"stop\" is not implemented!"

    # Returns a promise that is fulfilled when done.
    moveToPosition: (position) ->
      throw new Error "Function \"moveToPosition\" is not implemented!"

    moveByPercentage: (percentage) ->
      duration = @_calculateRollingTime(Math.abs(percentage))
      if duration is 0
        return Promise.resolve()

      promise = if percentage > 0 then @moveUp() else @moveDown()
      promise = promise.delay(duration + 10).then( () =>
        @stop()
      )
      return promise

    # Returns a promise that will be fulfilled with the position
    getPosition: -> Promise.resolve(@_position)

    _setPosition: (position) ->
      assert position in ['up', 'down', 'stopped']
      if @_position is position then return
      @_position = position
      @emit "position", position

    # calculates rolling time in ms for given percentage
    _calculateRollingTime: (percentage) ->
      assert 0 <= percentage <= 100, "percentage must be between 0 and 100"
      return @rollingTime * 1000 * percentage / 100 if @rollingTime?
      throw new Error "No rolling time configured."

  ###
  Sensor
  ------
  ###
  class Sensor extends Device

  ###
  TemperatureSensor
  ------
  ###
  class TemperatureSensor extends Sensor
    _temperature: undefined

    actions:
      getTemperature:
        description: "Returns the current temperature"
        returns:
          temperature:
            type: t.number

    attributes:
      temperature:
        description: "The measured temperature"
        type: t.number
        unit: '°C'
        acronym: 'T'

    _setTemperature: (value) ->
      @_temperature = value
      @emit 'temperature', value

    getTemperature: -> Promise.resolve(@_temperature)

    template: "temperature"

  ###
  PresenceSensor
  ------
  ###
  class PresenceSensor extends Sensor
    _presence: undefined

    actions:
      getPresence:
        description: "Returns the current presence state"
        returns:
          presence:
            type: t.boolean

    attributes:
      presence:
        description: "Presence of the human/device"
        type: t.boolean
        labels: ['present', 'absent']

    _setPresence: (value) ->
      if @_presence is value then return
      @_presence = value
      @emit 'presence', value

    getPresence: -> Promise.resolve(@_presence)

    template: "presence"

  ###
  ContactSensor
  ------
  ###
  class ContactSensor extends Sensor
    _contact: undefined

    actions:
      getContact:
        description: "Returns the current state of the contact"
        returns:
          contact:
            type: t.boolean

    attributes:
      contact:
        description: "State of the contact"
        type: t.boolean
        labels: ['closed', 'opened']

    template: "contact"

    _setContact: (value) ->
      if @_contact is value then return
      @_contact = value
      @emit 'contact', value

    getContact: -> Promise.resolve(@_contact)

  upperCaseFirst = (string) ->
    unless string.length is 0
      string[0].toUpperCase() + string.slice(1)
    else ""

  class HeatingThermostat extends Device

    attributes:
      temperatureSetpoint:
        label: "Temperature Setpoint"
        description: "The temp that should be set"
        type: "number"
        discrete: true
        unit: "°C"
      valve:
        description: "Position of the valve"
        type: "number"
        discrete: true
        unit: "%"
      mode:
        description: "The current mode"
        type: "string"
        enum: ["auto", "manu", "boost"]
      battery:
        description: "Battery status"
        type: "string"
        enum: ["ok", "low"]
      synced:
        description: "Pimatic and thermostat in sync"
        type: "boolean"

    actions:
      changeModeTo:
        params:
          mode:
            type: "string"
      changeTemperatureTo:
        params:
          temperatureSetpoint:
            type: "number"

    template: "thermostat"

    _mode: null
    _temperatureSetpoint: null
    _valve: null
    _battery: null
    _synced: false

    getMode: () -> Promise.resolve(@_mode)
    getTemperatureSetpoint: () -> Promise.resolve(@_temperatureSetpoint)
    getValve: () -> Promise.resolve(@_valve)
    getBattery: () -> Promise.resolve(@_battery)
    getSynced: () -> Promise.resolve(@_synced)

    _setMode: (mode) ->
      if mode is @_mode then return
      @_mode = mode
      @emit "mode", @_mode

    _setSynced: (synced) ->
      if synced is @_synced then return
      @_synced = synced
      @emit "synced", @_synced

    _setSetpoint: (temperatureSetpoint) ->
      if temperatureSetpoint is @_temperatureSetpoint then return
      @_temperatureSetpoint = temperatureSetpoint
      @emit "temperatureSetpoint", @_temperatureSetpoint

    _setValve: (valve) ->
      if valve is @_valve then return
      @_valve= valve
      @emit "valve", @_valve

    _setBattery: (battery) ->
      if battery is @_battery then return
      @_battery = battery
      @emit "battery", @_battery

    changeModeTo: (mode) ->
      throw new Error("changeModeTo must be implemented by a subclass")

    changeTemperatureTo: (temperatureSetpoint) ->
      throw new Error("changeTemperatureTo must be implemented by a subclass")

  class AVPlayer extends Device

    actions:
      play:
        description: "starts playing"
      pause:
        description: "pauses playing"
      stop:
        description: "stops playing"
      next:
        description: "play next song"
      previous:
        description: "play previous song"
      volume:
        description: "Change volume of player"

    attributes:
      currentArtist:
        description: "the current playing track artist"
        type: "string"
      currentTitle:
        description: "the current playing track title"
        type: "string"
      state:
        description: "the current state of the player"
        type: "string"
      volume:
        description: "the volume of the player"
        type: "string"

    _state: null
    _currentTitle: null
    _currentArtist: null
    _volume: null

    template: "musicplayer"

    _setState: (state) ->
      if @_state isnt state
        @_state = state
        @emit 'state', state

    _setCurrentTitle: (title) ->
      if @_currentTitle isnt title
        @_currentTitle = title
        @emit 'currentTitle', title

    _setCurrentArtist: (artist) ->
      if @_currentArtist isnt artist
        @_currentArtist = artist
        @emit 'currentArtist', artist

    _setVolume: (volume) ->
      if @_volume isnt volume
        @_volume = volume
        @emit 'volume', volume

    getState: () -> Promise.resolve @_state
    getCurrentTitle: () -> Promise.resolve(@_currentTitle)
    getCurrentArtist: () -> Promise.resolve(@_currentTitle)
    getVolume: ()  -> Promise.resolve(@_volume)

  class ButtonsDevice extends Device

    attributes:
      button:
        description: "The last pressed button"
        type: t.string

    actions:
      buttonPressed:
        params:
          buttonId:
            type: t.string
        description: "Press a button"

    template: "buttons"

    _lastPressedButton: null

    constructor: (@config, lastState)->
      @id = @config.id
      @name = @config.name
      
      super()
      
      @_lastPressedButton = lastState?.button?.value
      for button in @config.buttons
        @_button = button if button.id is @_lastPressedButton
    
    getButton: -> Promise.resolve(@_lastPressedButton)

    buttonPressed: (buttonId) ->
      for b in @config.buttons
        if b.id is buttonId
          @_lastPressedButton = b.id
          @emit 'button', b.id
          return Promise.resolve()
      throw new Error("No button with the id #{buttonId} found")

    destroy: () ->
      super()

  class InputDevice extends Device

    _input: ""

    template: "input"

    actions:
      changeInputTo:
        params:
          value:
            type: t.string
        description: "Sets the input value"

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @_inputType = @config.type or "string"

      @attributes = {
        input:
          description: "The value of the input field"
          type: @_inputType
      }

      @_defaultValue = if @_inputType is "string" then "" else 0
      @_input = lastState?.input?.value or @_defaultValue
      super()

    getInput: () -> Promise.resolve(@_input)

    _setInput: (value) ->
      unless @_input is value
        @_input = value
        @emit 'input', value

    changeInputTo: (value) ->
      if @config.type is "number"
        if isNaN(value)
          throw new Error("Input value is not a number")
        else
          @_setInput(parseFloat(value))
      else
        @_setInput value
      return Promise.resolve()

    destroy: ->
      super()

  class VariablesDevice extends Device

    constructor: (@config, lastState, @framework) ->
      @id = @config.id
      @name = @config.name
      @_vars = @framework.variableManager
      @_exprChangeListeners = []
      @attributes = {}
      for variable in @config.variables
        do (variable) =>
          name = variable.name
          info = null

          if @attributes[name]?
            throw new Error(
              "Two variables with the same name in VariablesDevice config \"#{name}\""
            )

          @attributes[name] = {
            description: name
            label: (if variable.label? then variable.label else "$#{name}")
            type: variable.type or "string"
          }

          if variable.unit? and variable.unit.length > 0
            @attributes[name].unit = variable.unit

          if variable.discrete?
            @attributes[name].discrete = variable.discrete

          if variable.acronym?
            @attributes[name].acronym = variable.acronym


          parseExprAndAddListener = ( () =>
            info = @_vars.parseVariableExpression(variable.expression)
            @_vars.notifyOnChange(info.tokens, onChangedVar)
            @_exprChangeListeners.push onChangedVar
          )

          evaluateExpr = ( (varsInEvaluation) =>
            if @attributes[name].type is "number"
              unless @attributes[name].unit? and @attributes[name].unit.length > 0
                @attributes[name].unit = @_vars.inferUnitOfExpression(info.tokens)
            switch info.datatype
              when "numeric" then @_vars.evaluateNumericExpression(info.tokens, varsInEvaluation)
              when "string" then @_vars.evaluateStringExpression(info.tokens, varsInEvaluation)
              else assert false
          )

          onChangedVar = ( (changedVar) =>
            evaluateExpr().then( (val) =>
              @emit name, val
            )
          )

          getValue = ( (varsInEvaluation) =>
            # wait till variableManager is ready
            return @_vars.waitForInit().then( =>
              unless info?
                parseExprAndAddListener()
              return evaluateExpr(varsInEvaluation)
            ).then( (val) =>
              if val isnt @_attributesMeta[name].value
                @emit name, val
              return val
            )
          )
          @_createGetter(name, getValue)
      super()

    destroy: ->
      @_vars.cancelNotifyOnChange(cl) for cl in @_exprChangeListeners
      super()

  class VariableInputDevice extends InputDevice

    actions:
      changeInputTo:
        params:
          value:
            type: t.string
        description: "Sets the variable to the value"

    constructor: (@config, lastState, @framework) ->
      super(@config, lastState)
      @_variableName = (@config.variable||'').replace /^[\s\$]+|[\s]$/g, ''

      @framework.variableManager.on('variableValueChanged', @changeListener = (changedVar, value) =>
        if @_variableName is changedVar.name
          @_setInput value
      )

    changeInputTo: (value) ->
      variable = @framework.variableManager.getVariableByName(@_variableName)
      unless variable?
        throw new Error("Could not find variable with name #{@_variableName}")
      @framework.variableManager.setVariableToValue(@_variableName, value, variable.unit)
      super(value)

    destroy: ->
      @framework.variableManager.removeListener('variableValueChanged', @changeListener)
      super()


  class VariableTimeInputDevice extends VariableInputDevice

    template: "inputTime"

    actions:
      changeInputTo:
        params:
          value:
            type: t.string
        description: "Sets the variable to the value"

    constructor: (@config, lastState, @framework) ->
      super(@config, lastState, @framework)

    changeInputTo: (value) ->
      variable = @framework.variableManager.getVariableByName(@_variableName)
      unless variable?
        throw new Error("Could not find variable with name #{@_variableName}")
      @framework.variableManager.setVariableToValue(@_variableName, value, variable.unit)
      timePattern = /// ^([01]?[0-9]|2[0-3]):[0-5][0-9] ///
      hourPattern = ///
            ^[01]?[0-9]|2[0-3] 
            ///

      if value.match timePattern
        @_setInput value
      else
        if value.match hourPattern
          @_setInput value "#{textValue}:00"
        else
          throw new Error("Input value is not a valid time")
      return Promise.resolve()

    destroy: ->
      super()


  class DummySwitch extends SwitchActuator

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @_state = lastState?.state?.value or off
      super()

    changeStateTo: (state) ->
      @_setState(state)
      return Promise.resolve()

    destroy: () ->
      super()


  class DummyDimmer extends DimmerActuator

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @_dimlevel = lastState?.dimlevel?.value or 0
      @_state = lastState?.state?.value or off
      super()

    # Returns a promise that is fulfilled when done.
    changeDimlevelTo: (level) ->
      @_setDimlevel(level)
      return Promise.resolve()

    destroy: () ->
      super()

  class DummyShutter extends ShutterController

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @rollingTime = @config.rollingTime
      @_position = lastState?.position?.value or 'stopped'
      super()

    stop: ->
      @_setPosition('stopped')
      return Promise.resolve()

    # Returns a promise that is fulfilled when done.
    moveToPosition: (position) ->
      @_setPosition(position)
      return Promise.resolve()

    destroy: () ->
      super()

  class DummyHeatingThermostat extends HeatingThermostat

    actions:
      changeModeTo:
        params:
          mode:
            type: "string"
      changeTemperatureTo:
        params:
          temperatureSetpoint:
            type: "number"
      changeValveTo:
        params:
          valve:
            type: "number"

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperatureSetpoint = lastState?.temperatureSetpoint?.value or 20
      @_mode = lastState?.mode?.value or "auto"
      @_battery = lastState?.battery?.value or "ok"
      @_synced = true
      super()

    changeModeTo: (mode) ->
      @_setMode(mode)
      return Promise.resolve()

    changeValveTo: (valve) ->
      @_setValve(valve)
      return Promise.resolve()

    changeTemperatureTo: (temperatureSetpoint) ->
      @_setSetpoint(temperatureSetpoint)
      return Promise.resolve()

    destroy: () ->
      super()

  class DummyPresenceSensor extends PresenceSensor

    actions:
      changePresenceTo:
        params:
          presence:
            type: "boolean"

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @_presence = lastState?.presence?.value or off
      @_triggerAutoReset()
      super()

    changePresenceTo: (presence) ->
      @_setPresence(presence)
      @_triggerAutoReset()
      return Promise.resolve()

    _triggerAutoReset: ->
      if @config.autoReset and @_presence
        clearTimeout(@_resetPresenceTimeout)
        @_resetPresenceTimeout = setTimeout(@_resetPresence, @config.resetTime)

    _resetPresence: =>
      @_setPresence(no)

    destroy: () ->
      clearTimeout(@_resetPresenceTimeout)
      super()


  class DummyContactSensor extends ContactSensor

    actions:
      changeContactTo:
        params:
          contact:
            type: "boolean"

    constructor: (@config, lastState) ->
      @name = @config.name
      @id = @config.id
      @_contact = lastState?.contact?.value or off
      super()

    changeContactTo: (contact) ->
      @_setContact(contact)
      return Promise.resolve()

    destroy: () ->
      super()

  class DummyTemperatureSensor extends TemperatureSensor

    _humidity: null

    attributes:
      temperature:
        description: "The measured temperature"
        type: t.number
        unit: '°C'
        acronym: 'T'
      humidity:
        description: "The actual degree of Humidity"
        type: t.number
        unit: '%'

    actions:
      changeTemperatureTo:
        params:
          temperature:
            type: "number"
      changeHumidityTo:
        params:
          humidity:
            type: "number"

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperature = lastState?.temperature?.value
      @_humidity = lastState?.humidity?.value
      super()

    _setHumidity: (value) ->
      @_humidity = value
      @emit 'humidity', value

    getHumidity: -> Promise.resolve(@_humidity)

    changeTemperatureTo: (temperature) ->
      @_setTemperature(temperature)
      return Promise.resolve()

    changeHumidityTo: (humidity) ->
      @_setHumidity(humidity)
      return Promise.resolve()

    destroy: () ->
      super()

  class Timer extends Device

    attributes:
      time:
        description: "The elapsed time"
        type: "number"
        unit: "s"
        displaySparkline: no
      running:
        description: "Is the timer running?"
        type: "boolean"

    actions:
      startTimer:
        description: "Starts the timer"
      stopTimer:
        description: "stops the timer"
      resetTimer:
        description: "reset the timer"

    template: "timer"

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_time = lastState?.time?.value or 0
      @_running = lastState?.running?.value or false
      @_setupInterval() if _running?
      super()

    resetTimer: () ->
      if @_time is 0
        return Promise.resolve()
      @_time = 0
      @emit 'time', 0
      return Promise.resolve()

    startTimer: () ->
      if @_running
        return Promise.resolve()
      @_running = true
      @emit 'running', true
      @_setupInterval()
      return Promise.resolve()

    stopTimer: () ->
      unless @_running
        return Promise.resolve()
      @_destroyInterval()
      @_running = false
      @emit 'running', false
      return Promise.resolve()

    getTime: () ->
      return Promise.resolve(@_time)

    getRunning: () ->
      return Promise.resolve(@_running)

    _setupInterval: ->
      if @_interval? then return
      res = @config.resolution
      onTick = =>
        @_time += res
        @emit 'time', @_time
      @_interval = setInterval(onTick, res * 1000)

    _destroyInterval: ->
      clearInterval(@_interval)
      @_interval = null

    destroy: ->
      @_destroyInterval()
      super()

  class DeviceConfigExtension
    extendConfigShema: (schema) ->
      unless schema.extensions? then return
      for name, def of @configSchema
        if name in schema.extensions
          schema.properties[name] = _.clone(def)

    applicable: (schema) ->
      unless schema.extensions? then return
      for name, def of @configSchema
        if name in schema.extensions
          return yes
      return false

  class ConfirmDeviceConfigExtention extends DeviceConfigExtension
    configSchema:
      xConfirm:
        description: "Triggering a device action needs a confirmation"
        type: "boolean"
        required: no

    apply: (config, device) -> #should be handled by the frontend

  class LinkDeviceConfigExtention extends DeviceConfigExtension
    configSchema:
      xLink:
        description: "Open this link if the device label is clicked on the frontend"
        type: "string"
        required: no

    apply: (config, device) -> #should be handled by the frontend

  class XButtonDeviceConfigExtension extends DeviceConfigExtension
    configSchema:
      xButton:
        description: "Label for xButton device extension"
        type: "string"
        required: no

    apply: (config, device) -> #should be handled by the frontend

  class PresentLabelConfigExtension extends DeviceConfigExtension
    configSchema:
      xPresentLabel:
        description: "The label for the present state"
        type: "string"
        required: no
      xAbsentLabel:
        description: "The label for the absent state"
        type: "string"
        required: no

    apply: (config, device) ->
      if config.xPresentLabel? or config.xAbsentLabel?
        device.attributes = _.cloneDeep(device.attributes)
        device.attributes.presence.labels[0] = config.xPresentLabel if config.xPresentLabel?
        device.attributes.presence.labels[1] = config.xAbsentLabel if config.xAbsentLabel?


  class SwitchLabelConfigExtension extends DeviceConfigExtension
    configSchema:
      xOnLabel:
        description: "The label for the on state"
        type: "string"
        required: no
      xOffLabel:
        description: "The label for the off state"
        type: "string"
        required: no

    apply: (config, device) ->
      if config.xOnLabel? or config.xOffLabel?
        device.attributes = _.cloneDeep(device.attributes)
        device.attributes.state.labels[0] = config.xOnLabel if config.xOnLabel?
        device.attributes.state.labels[1] = config.xOffLabel if config.xOffLabel?

  class ContactLabelConfigExtension extends DeviceConfigExtension
    configSchema:
      xClosedLabel:
        description: "The label for the closed state"
        type: "string"
        required: no
      xOpenedLabel:
        description: "The label for the opened state"
        type: "string"
        required: no

    apply: (config, device) ->
      if config.xOpenedLabel? or config.xClosedLabel?
        device.attributes = _.cloneDeep(device.attributes)
        device.attributes.contact.labels[0] = config.xClosedLabel if config.xClosedLabel?
        device.attributes.contact.labels[1] = config.xOpenedLabel if config.xOpenedLabel?

  class ShutterLabelConfigExtension extends DeviceConfigExtension
    configSchema:
      xUpLabel:
        description: "The label for the up position"
        type: "string"
        required: no
      xDownLabel:
        description: "The label for the down position"
        type: "string"
        required: no
      xStoppedLabel:
        description: "The label for the stopped position"
        type: "string"
        required: no

    apply: (config, device) ->
      if config.xUpLabel? or config.xDownLabel? or config.xStoppedLabel?
        device.attributes = _.cloneDeep(device.attributes)
        device.attributes.position.labels.up = config.xUpLabel if config.xUpLabel?
        device.attributes.position.labels.down = config.xDownLabel if config.xDownLabel?
        device.attributes.position.labels.stopped =
          config.xStoppedLabel if config.xStoppedLabel?

  class AttributeOptionsConfigExtension extends DeviceConfigExtension
    configSchema:
      xAttributeOptions:
        description: "Extra attribute options for one or more attributes"
        type: "array"
        required: no
        items:
          type: "object"
          required: ["name"]
          properties:
            name:
              description: "Name for the corresponding attribute."
              type: "string"
            displaySparkline:
              description: "Show a sparkline behind the numeric attribute"
              type: "boolean"
              required: false
            hidden:
              description: "Hide the attribute in the gui"
              type: "boolean"
              required: false
            displayFormat:
              description: """
                Override formatting conventions used by the GUI to display
                the value. Format outputs are: raw, fixed, localeString,
                and uptime
              """
              type: "string"
              required: false

    apply: (config, device) ->
      if config.xAttributeOptions?
        device.attributes = _.cloneDeep(device.attributes)
        for attrOpts in config.xAttributeOptions
          name = attrOpts.name
          attr = device.attributes[name]
          unless attr?
            env.logger.warn(
              "Can't apply xAttributeOptions for \"#{name}\". Device #{device.name}
              has no attribute with this name"
            )
            continue
          attr.displaySparkline = attrOpts.displaySparkline if attrOpts.displaySparkline?
          attr.hidden = attrOpts.hidden if attrOpts.hidden?
          attr.displayFormat = attrOpts.displayFormat if attrOpts.displayFormat?

  class DeviceManager extends events.EventEmitter
    devices: {}
    deviceClasses: {}
    deviceConfigExtensions: []

    constructor: (@framework, @devicesConfig) ->
      @deviceConfigExtensions.push(new ConfirmDeviceConfigExtention())
      @deviceConfigExtensions.push(new LinkDeviceConfigExtention())
      @deviceConfigExtensions.push(new XButtonDeviceConfigExtension())
      @deviceConfigExtensions.push(new PresentLabelConfigExtension())
      @deviceConfigExtensions.push(new SwitchLabelConfigExtension())
      @deviceConfigExtensions.push(new ContactLabelConfigExtension())
      @deviceConfigExtensions.push(new ShutterLabelConfigExtension())
      @deviceConfigExtensions.push(new AttributeOptionsConfigExtension())

    registerDeviceClass: (className, {configDef, createCallback, prepareConfig}) ->
      assert typeof className is "string", "className must be a string"
      assert typeof configDef is "object", "configDef must be an object"
      assert typeof createCallback is "function", "createCallback must be a function"
      assert(if prepareConfig? then typeof prepareConfig is "function" else true)
      assert typeof configDef.properties is "object", """
        configDef must have a property "properties"
      """
      configDef.properties.id = {
        description: "The ID for the device"
        type: "string"
      }
      configDef.properties.name = {
        description: "The name for the device"
        type: "string"
      }
      configDef.properties.class = {
        description: "The class to use for the device"
        type: "string"
      }
      pluginName = @framework.pluginManager.getCallingPlugin()

      for extension in @deviceConfigExtensions
        extension.extendConfigShema(configDef)

      @framework._normalizeScheme(configDef)
      @deviceClasses[className] = {
        prepareConfig
        configDef
        createCallback
        pluginName
      }

    updateDeviceOrder: (deviceOrder) ->
      assert deviceOrder? and Array.isArray deviceOrder
      @framework.config.devices = @devicesConfig = _.sortBy(@devicesConfig,  (device) =>
        index = deviceOrder.indexOf device.id
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @framework.saveConfig()
      @framework._emitDeviceOrderChanged(deviceOrder)
      return deviceOrder

    registerDevice: (device, isNew = true) ->
      assert device?
      assert device instanceof env.devices.Device
      assert device._constructorCalled

      unless device.logger?
        classInfo = @deviceClasses[device.config.class]
        if classInfo?
          pluginName = classInfo.pluginName
        else
          pluginName = @framework.pluginManager.getCallingPlugin()
        deviceLogger = env.logger.base.createSublogger([pluginName, device.config.class])
        device.logger = deviceLogger

      if isNew and @devices[device.id]?
        throw new Error("Duplicate device id \"#{device.id}\"")
      unless device.id.match /^[a-z0-9\-_]+$/i
        env.logger.warn """
          The id of #{device.id} contains a non alphanumeric letter or symbol.
          This could lead to errors.
        """
      for reservedWord in [" and ", " or "]
        if device.name.indexOf(reservedWord) isnt -1
          env.logger.warn """
            Name of device "#{device.id}" contains an "#{reservedWord}".
            This could lead to errors in rules.
          """

      unless device instanceof ErrorDevice
        if isNew
          env.logger.info "New device \"#{device.name}\"..."
        else
          env.logger.info "Recreating \"#{device.name}\"..."

      @devices[device.id]=device

      for attrName, attr of device.attributes
        do (attrName, attr) =>
          device.on(attrName, onChange = (value) =>
            @framework._emitDeviceAttributeEvent(device, attrName, attr,  new Date(), value)
          )

      @_checkDestroyFunction(device)
      device.afterRegister()
      @framework._emitDeviceAdded(device) if isNew
      return device

    _loadDevice: (deviceConfig, lastDeviceState, oldDevice = null) ->
      isNew = not oldDevice?
      classInfo = @deviceClasses[deviceConfig.class]
      unless classInfo?
        throw new Error("Unknown device class \"#{deviceConfig.class}\"")
      warnings = []
      classInfo.prepareConfig(deviceConfig) if classInfo.prepareConfig?
      @framework._normalizeScheme(classInfo.configDef)
      @framework._validateConfig(
        deviceConfig,
        classInfo.configDef,
          "config of device \"#{deviceConfig.id}\""
      )
      deviceConfig = declapi.enhanceJsonSchemaWithDefaults(classInfo.configDef, deviceConfig)

      deviceLogger = env.logger.base.createSublogger([classInfo.pluginName, deviceConfig.class])

      if oldDevice? and not oldDevice._destroyed
        oldDevice.destroy()
        assert(
          oldDevice._destroyed,
          "The device subclass #{oldDevice.config.class} did not call super() in destroy()"
        )

      device = classInfo.createCallback(deviceConfig, lastDeviceState, deviceLogger)
      device.logger = deviceLogger
      assert deviceConfig is device.config, """
        You must assign the config to your device in the the constructor function of your device:
        "@config = config"
      """
      for name, valueAndTime of lastDeviceState
        if device.attributes[name]?
          meta = device._attributesMeta[name]
          unless meta? then continue
          # Do not set `meta.value` here, because internal state and meta could be divergent
          # Should be better handled in a new pimatic "major" version
          meta.history = [t:valueAndTime.time, v: valueAndTime.value]

      for extension in @deviceConfigExtensions
        if extension.applicable(classInfo.configDef)
          extension.apply(device.config, device)

      return @registerDevice(device, isNew)

    _loadErrorDevice: (deviceConfig, error) ->
      return @registerDevice(new ErrorDevice(deviceConfig, error))

    loadDevices: ->
      return Promise.each(@devicesConfig, (deviceConfig) =>
        @framework.database.getLastDeviceState(deviceConfig.id).then( (lastDeviceState) =>
          classInfo = @deviceClasses[deviceConfig.class]
          if classInfo?
            try
              @_loadDevice(deviceConfig, lastDeviceState)
            catch e
              env.logger.error("Error loading device \"#{deviceConfig.id}\": #{e.message}")
              env.logger.debug(e.stack)
              @_loadErrorDevice(deviceConfig, e.message)
          else
            env.logger.warn("""
              No plugin found for device "#{deviceConfig.id}" of class "#{deviceConfig.class}"!
            """)
            @_loadErrorDevice(deviceConfig, "Plugin not loaded")
        )
      )


    getDeviceById: (id) -> @devices[id]

    getDevices: -> (device for id, device of @devices)

    getDeviceClasses: -> (className for className of @deviceClasses)

    getDeviceConfigSchema: (className)-> @deviceClasses[className]?.configDef

    addDeviceByConfig: (deviceConfig) ->
      assert deviceConfig.id?
      assert deviceConfig.class?
      if @isDeviceInConfig(deviceConfig.id)
        throw new Error(
          "A device with the ID \"#{deviceConfig.id}\" is already in the config."
        )
      device = @_loadDevice(deviceConfig, {})
      @addDeviceToConfig(deviceConfig)
      return device

    _checkDestroyFunction: (device) ->
      if device.destroy is Device.prototype.destroy
        deviceClass = device.config.class
        unless @_alreadyWarnedFor?
          @_alreadyWarnedFor = {}
        if @_alreadyWarnedFor[deviceClass]?
          return
        @_alreadyWarnedFor[deviceClass] = true
        env.logger.warn("The device type #{deviceClass} does not implement a destroy function")

    recreateDevice: (oldDevice, newDeviceConfig) ->
      return @framework.database.getLastDeviceState(oldDevice.id).then( (lastDeviceState) =>
        loadDeviceError = null
        try
          newDevice = @_loadDevice(newDeviceConfig, lastDeviceState, oldDevice)
        catch err
          loadDeviceError = err
          if oldDevice._destroyed
            # the old device was destroyed but there was an error creating the new device,
            # we have to recreate the original (old) device
            try
              newDevice = @_loadDevice(oldDevice.config, lastDeviceState, oldDevice)
            catch err
              # we failed to restore the old destroyed device, we log this error and
              # rethrow the first error
              logger = oldDevice.logger or env.logger
              logger.error("Error restoring changed device #{oldDevice.id}: #{err.message}")
              logger.debug(err.stack)
              throw loadDeviceError
          else
            # the old device was not destroyed, so just throw the load device error
            throw loadDeviceError
        
        oldDevice.emit 'changed', newDevice
        @emit 'deviceChanged', newDevice

        # rethrow the error if the creation of the device with the new config failed
        if loadDeviceError?
          throw loadDeviceError
        return newDevice
      )

    discoverDevices: (time = 20000) ->
      env.logger.info("Starting device discovery for #{time}ms.")
      @emit 'discover', {time}

    discoverMessage: (pluginName, message) ->
      env.logger.info("#{pluginName}: #{message}")
      @emit 'discoverMessage', {pluginName, message}

    discoveredDevice: (pluginName, deviceName, config) ->
      env.logger.info("Device discovered: #{pluginName}: #{deviceName}")
      @emit 'deviceDiscovered', {pluginName, deviceName, config}

    updateDeviceByConfig: (deviceConfig) ->
      unless deviceConfig.id?
        throw new Error("No id given")
      device = @getDeviceById(deviceConfig.id)
      unless device?
        throw new Error("device not found: #{deviceConfig.id}")
      return @recreateDevice(device, deviceConfig)

    removeDevice: (deviceId) ->
      device = @getDeviceById(deviceId)
      unless device? then return
      delete @devices[deviceId]
      @emit 'deviceRemoved', device
      device.emit 'remove'
      device.destroy()
      assert(
        device._destroyed,
        "The device subclass #{device.config.class} did not call super() in destroy()"
      )
      device.emit 'destroyed'
      return device

    addDeviceToConfig: (deviceConfig) ->
      assert deviceConfig.id?
      assert deviceConfig.class?

      # Check if device is already in the deviceConfig:
      present = @isDeviceInConfig deviceConfig.id
      if present
        throw new Error(
          "An device with the ID #{deviceConfig.id} is already in the config"
        )
      @devicesConfig.push deviceConfig
      @framework.saveConfig()


    callDeviceActionReq: (params, req) =>
      deviceId = req.params.deviceId
      actionName = req.params.actionName
      device = @getDeviceById(deviceId)
      unless device?
        throw new Error("device not found: #{deviceId}")
      unless device.hasAction(actionName)
        throw new Error('device hasn\'t that action')
      action = device.actions[actionName]
      return declapi.callActionFromReq(actionName, action, device, req)

    callDeviceActionSocket: (params, call) =>
      deviceId = call.params.deviceId
      actionName = call.params.actionName
      device = @getDeviceById(deviceId)
      unless device?
        throw new Error("device not found: #{deviceId}")
      unless device.hasAction(actionName)
        throw new Error('device hasn\'t that action')
      action = device.actions[actionName]
      call = _.clone(call)
      call.action = actionName
      return declapi.callActionFromSocket(device, action, call)

    isDeviceInConfig: (id) ->
      assert id?
      for d in @devicesConfig
        if d.id is id then return true
      return false

    initDevices: ->
      deviceConfigDef = require("../device-config-schema")
      defaultDevices = [
        env.devices.ButtonsDevice
        env.devices.InputDevice
        env.devices.VariablesDevice
        env.devices.VariableInputDevice
        env.devices.VariableTimeInputDevice
        env.devices.DummySwitch
        env.devices.DummyDimmer
        env.devices.DummyShutter
        env.devices.DummyHeatingThermostat
        env.devices.DummyContactSensor
        env.devices.DummyPresenceSensor
        env.devices.DummyTemperatureSensor
        env.devices.Timer
      ]
      for deviceClass in defaultDevices
        do (deviceClass) =>
          @registerDeviceClass(deviceClass.name, {
            configDef: deviceConfigDef[deviceClass.name],
            createCallback: (config, lastState) =>
              return new deviceClass(config, lastState, @framework)
          })

  return exports = {
    DeviceManager
    Device
    ErrorDevice
    Actuator
    SwitchActuator
    PowerSwitch
    DimmerActuator
    ShutterController
    Sensor
    TemperatureSensor
    PresenceSensor
    ContactSensor
    HeatingThermostat
    ButtonsDevice
    InputDevice
    VariablesDevice
    VariableInputDevice
    VariableTimeInputDevice
    AVPlayer
    DummySwitch
    DummyDimmer
    DummyShutter
    DummyHeatingThermostat
    DummyContactSensor
    DummyPresenceSensor
    DummyTemperatureSensor
    Timer
    DeviceConfigExtension
  }
