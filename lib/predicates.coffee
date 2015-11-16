###
Predicate Provider
=================
A Predicate Provider provides a predicate for the Rule System. For predicate and rule explanations
take a look at the [rules file](rules.html). A predicate is a string that describes a state. A
predicate is either true or false at a given time. There are special predicates, 
called event-predicates, that represent events. These predicate are just true in the moment a 
special event happen.
###

__ = require("i18n").__
Promise = require 'bluebird'
S = require 'string'
assert = require 'cassert'
_ = require 'lodash'
M = require './matcher'
types = require('decl-api').types

module.exports = (env) ->

  ###
  The Predicate Provider
  ----------------
  This is the base class for all predicate provider. 
  ###
  class PredicateProvider

    parsePredicate: (input, context) -> throw new Error("You must implement parsePredicate")


  class PredicateHandler extends require('events').EventEmitter

    getType: -> throw new Error("You must implement getType")
    getValue: -> throw new Error("You must implement getValue")

    setup: -> 
      # You must overwrite this method and set up your listener here.
      # You should call super() after that.
      if @_setupCalled then throw new Error("Setup already called!")
      @_setupCalled = yes
    destroy: -> 
      # You must overwrite this method and remove your listener here.
      # You should call super() after that.
      unless @_setupCalled then throw new Error("Destroy called, but setup was not called!")
      delete @_setupCalled

  ###
  The Switch Predicate Provider
  ----------------
  Provides predicates for the state of switch devices like:

  * _device_ is on|off
  * _device_ is switched on|off
  * _device_ is turned on|off

  ####
  class SwitchPredicateProvider extends PredicateProvider

    presets: [
      {
        name: "switch turned on/off"
        input: "{device} is turned on"
      }
    ]

    constructor: (@framework) ->

    # ### parsePredicate()
    parsePredicate: (input, context) ->  

      switchDevices = _(@framework.deviceManager.devices).values()
        .filter((device) => device.hasAttribute( 'state')).value()

      device = null
      state = null
      match = null

      stateAcFilter = (v) => v.trim() isnt 'is switched' 
      M(input, context)
        .matchDevice(switchDevices, (next, d) =>
          next.match([' is', ' is turned', ' is switched'], acFilter: stateAcFilter, type: 'static')
            .match([' on', ' off'], param: 'state', type: 'select', (next, s) =>
              # Already had a match with another device?
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              assert d?
              assert s in [' on', ' off']
              device = d
              state = s.trim() is 'on'
              match = next.getFullMatch()
          )
        )
 
      # If we have a match
      if match?
        assert device?
        assert state?
        assert typeof match is "string"
        # and state as boolean.
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new SwitchPredicateHandler(device, state)
        }
      else
        return null

  class SwitchPredicateHandler extends PredicateHandler

    constructor: (@device, @state) ->
    setup: ->
      @stateListener = (s) => @emit 'change', (s is @state)
      @device.on 'state', @stateListener
      super()
    getValue: -> @device.getUpdatedAttributeValue('state').then( (s) => (s is @state) )
    destroy: -> 
      @device.removeListener "state", @stateListener
      super()
    getType: -> 'state'


  ###
  The Presence Predicate Provider
  ----------------
  Handles predicates of presence devices like

  * _device_ is present
  * _device_ is not present
  * _device_ is absent
  ####
  class PresencePredicateProvider extends PredicateProvider

    presets: [
      {
        name: "device is present/absent"
        input: "{device} is present"
      }
    ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      presenceDevices = _(@framework.deviceManager.devices).values()
        .filter((device) => device.hasAttribute( 'presence')).value()

      device = null
      negated = null
      match = null

      stateAcFilter = (v) => v.trim() isnt 'not present'

      M(input, context)
        .matchDevice(presenceDevices, (next, d) =>
          next.match([' is', ' reports', ' signals'], type: "static")
            .match(
              [' present', ' absent', ' not present'], 
              acFilter: stateAcFilter, type: "select", param: "state", 
              (m, s) =>
                # Already had a match with another device?
                if device? and device.id isnt d.id
                  context?.addError(""""#{input.trim()}" is ambiguous.""")
                  return
                device = d
                negated = (s.trim() isnt "present") 
                match = m.getFullMatch()
            )
      )
      
      if match?
        assert device?
        assert negated?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new PresencePredicateHandler(device, negated)
        }
      else
        return null

  class PresencePredicateHandler extends PredicateHandler

    constructor: (@device, @negated) ->

    setup: ->
      @presenceListener = (p) => 
        @emit 'change', (if @negated then not p else p)
      @device.on 'presence', @presenceListener
      super()
    getValue: -> 
      return @device.getUpdatedAttributeValue('presence').then( 
        (p) => (if @negated then not p else p)
      )
    destroy: -> 
      @device.removeListener "presence", @presenceListener
      super()
    getType: -> 'state'

  ###
  The Contact Predicate Provider
  ----------------
  Handles predicates of contact devices like

  * _device_ is opened
  * _device_ is closed
  ####
  class ContactPredicateProvider extends PredicateProvider

    presets: [
      {
        name: "device is opened/closed"
        input: "{device} is opened"
      }
    ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      contactDevices = _(@framework.deviceManager.devices).values()
        .filter((device) => device.hasAttribute( 'contact')).value()

      device = null
      negated = null
      match = null

      contactAcFilter = (v) => v.trim() in ['opened', 'closed']

      M(input, context)
        .matchDevice(contactDevices, (next, d) =>
          next.match(' is', type: "static")
            .match(
              [' open', ' close', ' opened', ' closed'], 
              acFilter: contactAcFilter, type: "select", 
              (m, s) =>
                # Already had a match with another device?
                if device? and device.id isnt d.id
                  context?.addError(""""#{input.trim()}" is ambiguous.""")
                  return
                device = d
                negated = (s.trim() in ["opened", 'open']) 
                match = m.getFullMatch()
            )
      )
      
      if match?
        assert device?
        assert negated?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length),
          predicateHandler: new ContactPredicateHandler(device, negated)
        }
      else
        return null

  class ContactPredicateHandler extends PredicateHandler

    constructor: (@device, @negated) ->

    setup: ->
      @contactListener = (p) => 
        @emit 'change', (if @negated then not p else p)
      @device.on 'contact', @contactListener
      super()
    getValue: -> @device.getUpdatedAttributeValue('contact').then(
      (p) => (if @negated then not p else p)
    )
    destroy: -> 
      @device.removeListener "contact", @contactListener
      super()
    getType: -> 'state'


  ###
  The Device-Attribute Predicate Provider
  ----------------
  Handles predicates for comparing device attributes like sensor values or other states:

  * _attribute_ of _device_ is equal to _value_
  * _attribute_ of _device_ equals _value_
  * _attribute_ of _device_ is not _value_
  * _attribute_ of _device_ is less than _value_
  * _attribute_ of _device_ is lower than _value_
  * _attribute_ of _device_ is greater than _value_
  * _attribute_ of _device_ is higher than _value_
  ####
  class DeviceAttributePredicateProvider extends PredicateProvider
    
    presets: [
      {
        name: "attribute of a device"
        input: "{attribute} of {device} is equal to {value}"
      }
    ]

    constructor: (@framework) ->

    # ### parsePredicate()
    parsePredicate: (input, context) ->

      allAttributes = _(@framework.deviceManager.getDevices())
        .map((device) => _.keys(device.attributes))
        .flatten().uniq().value()

      result = null
      matches = []

      M(input, context)
      .match(
        allAttributes,
        param: "attribute", wildcard: "{attribute}"
        (m, attr) =>
          info = {
            device: null
            attributeName: null
            comparator: null
            referenceValue: null
          }
          info.attributeName = attr
          devices = _(@framework.deviceManager.devices).values()
            .filter((device) => device.hasAttribute(attr)).value()

          m.match(' of ').matchDevice(devices, (next, device) =>
            info.device = device
            unless device.hasAttribute(attr) then return
            attribute = device.attributes[attr]
            setComparator =  (m, c) => info.comparator = c
            setRefValue = (m, v) => info.referenceValue = v
            end =  => matchCount++

            if attribute.type is types.boolean
              m = next.matchComparator('boolean', setComparator)
                .match(attribute.labels, wildcard: '{value}', (m, v) =>
                  if v is attribute.labels[0] then setRefValue(m, true)
                  else if v is attribute.labels[1] then setRefValue(m, false)
                  else assert(false)
              )
            else if attribute.type is types.number
              m = next.matchComparator('number', setComparator)
                .matchNumber(wildcard: '{value}', (m,v) => setRefValue(m, parseFloat(v)) )
              if attribute.unit? and attribute.unit.length > 0 
                possibleUnits = _.uniq([
                  " #{attribute.unit}", 
                  "#{attribute.unit}", 
                  "#{attribute.unit.toLowerCase()}", 
                  " #{attribute.unit.toLowerCase()}",
                  "#{attribute.unit.replace('°', '')}", 
                  " #{attribute.unit.replace('°', '')}",
                  "#{attribute.unit.toLowerCase().replace('°', '')}", 
                  " #{attribute.unit.toLowerCase().replace('°', '')}",
                  ])
                autocompleteFilter = (v) => v is " #{attribute.unit}"
                m = m.match(possibleUnits, {optional: yes, acFilter: autocompleteFilter})
            else if attribute.type is types.string
              m = next.matchComparator('string', setComparator)
                .or([
                  ( (m) => m.matchString(wildcard: '{value}', setRefValue) ),
                  ( (m) => 
                    if attribute.enum?
                      m.match(attribute.enum, wildcard: '{value}', setRefValue) 
                    else M(null) 
                  )
                ])
            if m.hadMatch()
              matches.push m.getFullMatch()
              if result?
                if result.device.id isnt info.device.id or 
                result.attributeName isnt info.attributeName
                  context?.addError(""""#{input.trim()}" is ambiguous.""")
              result = info
          )
      )

      if result?
        assert result.device?
        assert result.attributeName?
        assert result.comparator?
        assert result.referenceValue?
        # take the longest match
        match = _(matches).sortBy( (s) => s.length ).last()
        assert typeof match is "string" 

        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new DeviceAttributePredicateHandler(
            result.device, result.attributeName, result.comparator, result.referenceValue
          )
        }
        
      return null


  class DeviceAttributePredicateHandler extends PredicateHandler

    constructor: (@device, @attribute, @comparator, @referenceValue) ->

    setup: ->
      lastState = null
      @attributeListener = (value) =>
        state = @_compareValues(@comparator, value, @referenceValue)
        if state isnt lastState
          lastState = state
          @emit 'change', state
      @device.on @attribute, @attributeListener
      super()
    getValue: -> 
      @device.getUpdatedAttributeValue(@attribute).then( (value) =>
        @_compareValues(@comparator, value, @referenceValue)
      )
    destroy: -> 
      @device.removeListener @attribute, @attributeListener
      super()
    getType: -> 'state'

    # ### _compareValues()
    ###
    Does the comparison.
    ###
    _compareValues: (comparator, value, referenceValue) ->
      if typeof referenceValue is "number"
        value = parseFloat(value)
      result = switch comparator
        when '==' then value is referenceValue
        when '!=' then value isnt referenceValue
        when '<' then value < referenceValue
        when '>' then value > referenceValue
        when '<=' then value <= referenceValue
        when '>=' then value >= referenceValue
        else throw new Error "Unknown comparator: #{comparator}"
      return result


  ###
  The Device-Attribute Watchdog Provider
  ----------------
  Handles predicates that will become true if a attribute of a device was not updated for a
  certain time.

  * _attribute_ of _device_ was not updated for _time_
  ####
  class DeviceAttributeWatchdogProvider extends PredicateProvider

    presets: [
      {
        name: "attribute of a device not updated"
        input: "{attribute} of {device} was not updated for {duration} minutes"
      }
    ]

    constructor: (@framework) ->

    # ### parsePredicate()
    parsePredicate: (input, context) ->

      allAttributes = _(@framework.deviceManager.getDevices())
        .map((device) => _.keys(device.attributes))
        .flatten().uniq().value()

      result = null
      match = null

      M(input, context)
      .match(allAttributes, wildcard: "{attribute}", type: "select", (m, attr) =>
        info = {
          device: null
          attributeName: null
          timeMs: null
        }

        info.attributeName = attr
        devices = _(@framework.deviceManager.devices).values()
          .filter( (device) => device.hasAttribute(attr) ).value()
        m.match(' of ').matchDevice(devices, (m, device) =>
          info.device = device
          unless device.hasAttribute(attr) then return
          attribute = device.attributes[attr]

          m.match(' was not updated for ', type: "static")
            .matchTimeDuration(wildcard: "{duration}", type: "text", (m, {time, unit, timeMs}) =>
              info.timeMs = timeMs
              result = info
              match = m.getFullMatch()
            )
        )
      )

      if result?
        assert result.device?
        assert result.attributeName?
        assert result.timeMs?

        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new DeviceAttributeWatchdogPredicateHandler(
            result.device, result.attributeName, result.timeMs
          )
        }
        
      return null


  class DeviceAttributeWatchdogPredicateHandler extends PredicateHandler

    constructor: (@device, @attribute, @timeMs) ->

    setup: ->
      @_state = false
      @_rescheduleTimeout()
      @attributeListener = ( => 
        if @_state is true
          @_state = false
          @emit 'change', false
        @_rescheduleTimeout() 
      )
      @device.on @attribute, @attributeListener
      super()
    getValue: -> Promise.resolve(@_state)
    destroy: -> 
      @device.removeListener @attribute, @attributeListener
      clearTimeout(@_timer)
      super()
    getType: -> 'state'

    _rescheduleTimeout: ->
      clearTimeout(@_timer)
      @_timer = setTimeout( ( =>
        @_state = true
        @emit 'change', true 
      ), @timeMs)

  ###
  The Variable Predicate Provider
  ----------------
  Handles comparison of variables
  ####
  class VariablePredicateProvider extends PredicateProvider

    presets: [
        {
          name: "Variable comparison"
          input: "{expr} = {expr}"
        }
      ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      result = null

      M(input, context)
        .matchAnyExpression( (next, leftTokens) =>
          next.matchComparator('number', (next, comparator) =>
            next.matchAnyExpression( (next, rightTokens) =>
              result = {
                leftTokens
                rightTokens
                comparator
                match: next.getFullMatch()
              }
            )
          )
        )
      
      if result?
        assert Array.isArray result.leftTokens
        assert Array.isArray result.rightTokens
        assert result.comparator in ['==', '!=', '<', '>', '<=', '>=']
        assert typeof result.match is "string"

        variables = @framework.variableManager.extractVariables(
          result.leftTokens.concat result.rightTokens
        )
        for v in variables?
          unless @framework.variableManager.isVariableDefined(v)
            context.addError("Variable $#{v} is not defined.")
            return null

        return {
          token: result.match
          nextInput: input.substring(result.match.length)
          predicateHandler: new VariablePredicateHandler(
            @framework, result.leftTokens, result.rightTokens, result.comparator
          )
        }
      else
        return null

  class VariablePredicateHandler extends PredicateHandler

    constructor: (@framework, @leftTokens, @rightTokens, @comparator) ->

    setup: ->
      @lastState = null
      @variables = @framework.variableManager.extractVariables(
        @leftTokens.concat @rightTokens
      )
      @changeListener = (variable, value) =>
        unless variable.name in @variables then return
        evalPromise = @_evaluate()
        evalPromise.then( (state) =>
          if state isnt @lastState
            @lastState = state
            @emit 'change', state
        ).catch( (error) =>
          env.logger.error "Error in VariablePredicateHandler:", error.message
          env.logger.debug error
        )
      
      @framework.variableManager.on("variableValueChanged", @changeListener)
      super()
    getValue: -> 
      return @_evaluate()
    destroy: -> 
      @framework.variableManager.removeListener("variableValueChanged", @changeListener)
      super()
    getType: -> 'state'

    _evaluate: ->
      leftPromise = @framework.variableManager.evaluateExpression(@leftTokens)
      rightPromise = @framework.variableManager.evaluateExpression(@rightTokens)
      return Promise.all([leftPromise, rightPromise]).then( ([leftValue, rightValue]) =>
        return state = @_compareValues(leftValue, rightValue)
      )

    # ### _compareValues()
    ###
    Does the comparison.
    ###
    _compareValues: (left, right) ->
      if @comparator in ["<", ">", "<=", ">="]
        if typeof left is "string"
          if isNaN(left)
            throw new Error("Can not compare strings with #{@comparator}!")
          left = parseFloat(left)
        if typeof right is "string"
          if isNaN(right)
            throw new Error("Can not compare strings with #{@comparator}!")
          right = parseFloat(right)

      return switch @comparator
        when '==' then left is right
        when '!=' then left isnt right
        when '<' then left < right
        when '>' then left > right
        when '<=' then left <= right
        when '>=' then left >= right
        else throw new Error "Unknown comparator: #{@comparator}"


  class VariableUpdatedPredicateProvider extends PredicateProvider

    presets: [
        {
          name: "Variable changes"
          input: "{variable} changes"
        }
        {
          name: "Variable increased/decreased"
          input: "{variable} increased"
        }
      ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      variableName = null
      mode = null

      setVariableName = (next, name) => variableName = name.substring(1)
      setMode = (next, match) => mode = match.trim()

      m = M(input, context)
        .matchVariable(setVariableName)
        .match([
          " changes", " gets updated", 
          " increased", " decreased", 
          " is increasing", " is decreasing"
        ], setMode)

      if m.hadMatch()
        match = m.getFullMatch()
        assert typeof variableName is "string"
        assert mode?
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new VariableUpdatedPredicateHandler(
            @framework, variableName, mode
          )
        }
      else
        return null

  class VariableUpdatedPredicateHandler extends PredicateHandler

    constructor: (@framework, @variableName, @mode) ->

    setup: ->
      @lastValue = null
      @state = false
      @changeListener = (variable, value) =>
        unless variable.name is @variableName then return
        switch @mode
          when 'changes'
            if @lastValue isnt value
              @emit 'change', "event"
          when 'gets updated'
            @emit 'change', "event"
          when 'increased'
            if value > @lastValue
              @emit 'change', "event"
          when 'decreased'
            if value < @lastValue
              @emit 'change', "event"
          when 'is increasing'
            if value > @lastValue
              if not @state
                @state = true
                @emit 'change', true
            else
              if @state
                @state = false
                @emit 'change', false
          when 'is decreasing'
            if value < @lastValue
              if not @state
                @state = true
                @emit 'change', true
            else
              if @state
                @state = false
                @emit 'change', false
        @lastValue = value
       
      @framework.variableManager.on("variableValueChanged", @changeListener)
      super()
    getValue: -> Promise.resolve(@state)
    destroy: ->
      @framework.variableManager.removeListener("variableValueChanged", @changeListener)
      super()
    getType: -> 
      switch @mode
        when 'is increasing', 'is decreasing' then return 'state'
        else return 'event'

  class ButtonPredicateProvider extends PredicateProvider

    presets: [
        {
          name: "Button pressed"
          input: "{button} is pressed"
        }
      ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      matchCount = 0
      matchingDevice = null
      matchingButtonId = null
      end = () => matchCount++
      onButtonMatch = (m, {device, buttonId}) =>
        matchingDevice = device
        matchingButtonId = buttonId

      buttonsWithId = [] 

      for id, d of @framework.deviceManager.devices
        continue unless d instanceof env.devices.ButtonsDevice
        for b in d.config.buttons
          buttonsWithId.push [{device: d, buttonId: b.id}, b.id]
          buttonsWithId.push [{device: d, buttonId: b.id}, b.text] if b.id isnt b.text

      m = M(input, context)
        .match('the ', optional: true)
        .match(
          buttonsWithId, 
          wildcard: "{button}"
          onButtonMatch
        )
        .match(' button', optional: true)
        .match(' is', optional: true)
        .match(' pressed')

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new ButtonPredicateHandler(this, matchingDevice, matchingButtonId)
        }
      return null

  class ButtonPredicateHandler extends PredicateHandler

    constructor: (@provider, @device, @buttonId) ->
      assert @device? and @device instanceof env.devices.ButtonsDevice
      assert @buttonId? and typeof @buttonId is "string"

    setup: ->
      @buttonPressedListener = ( (id) =>
        if id is @buttonId
          @emit 'change', 'event'
      )
      @device.on 'button', @buttonPressedListener
      super()

    getValue: -> Promise.resolve(false)
    destroy: -> 
      @device.removeListener 'button', @buttonPressedListener
      super()
    getType: -> 'event'


  class StartupPredicateProvider extends PredicateProvider

    presets: [
        {
          name: "pimatic is starting"
          input: "pimatic is starting"
        }
      ]

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      m = M(input, context).match(["pimatic is starting"])

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new StartupPredicateHandler(@framework)
        }
      else
        return null

  class StartupPredicateHandler extends PredicateHandler

    constructor: (@framework) ->

    setup: ->
      @framework.once "after init", =>
        @emit 'change', "event"
      super()
    getValue: -> Promise.resolve(false)
    getType: -> 'event'

  return exports = {
    PredicateProvider
    PredicateHandler
    PresencePredicateProvider
    SwitchPredicateProvider
    DeviceAttributePredicateProvider
    VariablePredicateProvider
    VariableUpdatedPredicateProvider
    ContactPredicateProvider
    ButtonPredicateProvider
    DeviceAttributeWatchdogProvider
    StartupPredicateProvider
  }
