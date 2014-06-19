###
Predicate Provider
=================
A Predicate Provider provides a predicate for the Rule System. For predicate and rule explenations
take a look at the [rules file](rules.html). A predicate is a string that describes a state. A
predicate is either true or false at a given time. There are special predicates, 
called event-predicates, that represent events. These predicate are just true in the moment a 
special event happen.
###

__ = require("i18n").__
Q = require 'q'
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
      if @_setupCalled then throw new Error("setup already called!")
      @_setupCalled = yes
    destroy: -> 
      # You must overwrite this method and remove your listener here.
      # You should call super() after that.
      unless @_setupCalled then throw new Error("destroy called but not setup called!")
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

    constructor: (@framework) ->

    # ### parsePredicate()
    parsePredicate: (input, context) ->  

      switchDevices = _(@framework.devices).values()
        .filter((device) => device.hasAttribute( 'state')).value()

      device = null
      state = null
      match = null

      stateAcFilter = (v) => v.trim() isnt 'is switched' 

      M(input, context)
        .matchDevice(switchDevices, (next, d) =>
          next.match([' is', ' is turned', ' is switched'], acFilter: stateAcFilter)
            .match([' on', ' off'], (next, s) =>
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

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      presenceDevices = _(@framework.devices).values()
        .filter((device) => device.hasAttribute( 'presence')).value()

      device = null
      negated = null
      match = null

      stateAcFilter = (v) => v.trim() isnt 'not present'

      M(input, context)
        .matchDevice(presenceDevices, (next, d) =>
          next.match([' is', ' reports', ' signals'])
            .match([' present', ' absent', ' not present'], {acFilter: stateAcFilter}, (m, s) =>
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

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      contactDevices = _(@framework.devices).values()
        .filter((device) => device.hasAttribute( 'contact')).value()

      device = null
      negated = null
      match = null

      contactAcFilter = (v) => v.trim() in ['opened', 'closed']

      M(input, context)
        .matchDevice(contactDevices, (next, d) =>
          next.match(' is')
            .match([' open', ' close', ' opened', ' closed'], {acFilter: contactAcFilter}, (m, s) =>
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
          nextInput: input.substring(match.length)
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
  Handles predicates for comparing device attributes like sensor value or other states:

  * _attribute_ of _device_ is equal to _value_
  * _attribute_ of _device_ equals _value_
  * _attribute_ of _device_ is not _value_
  * _attribute_ of _device_ is less than _value_
  * _attribute_ of _device_ is lower than _value_
  * _attribute_ of _device_ is greater than _value_
  * _attribute_ of _device_ is higher than _value_
  ####
  class DeviceAttributePredicateProvider extends PredicateProvider

    constructor: (@framework) ->

    # ### _parsePredicate()
    ###
    Parses the string and setups the info object as explained in the DeviceEventPredicateProvider.
    Read the description of it to understand the return value.
    ###
    parsePredicate: (input, context) ->

      allAttributes = _(@framework.devices).values().map((device) => _.keys(device.attributes))
        .flatten().uniq().value()

      result = null
      matches = []

      M(input, context)
      .match(allAttributes, (m, attr) =>
        info = {
          device: null
          attributeName: null
          comparator: null
          referenceValue: null
        }

        info.attributeName = attr
        devices = _(@framework.devices).values()
          .filter((device) => device.hasAttribute(attr)).value()
        m.match(' of ').matchDevice(devices, (m, device) =>
          info.device = device
          unless device.hasAttribute(attr) then return
          attribute = device.attributes[attr]

          setComparator =  (m, c) => info.comparator = c
          setRefValue = (m, v) => info.referenceValue = v
          end =  => matchCount++

          if attribute.type is types.boolean
            m = m.matchComparator('boolean', setComparator).match(attribute.labels, (m, v) =>
              if v is attribute.labels[0] then setRefValue(m, true)
              else if v is attribute.labels[1] then setRefValue(m, false)
              else assert(false)
            )
          else if attribute.type is types.number
            m = m.matchComparator('number', setComparator)
              .matchNumber( (m,v) => setRefValue(m, parseFloat(v)) )
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
            m = m.matchComparator('string', setComparator)
              .or([
                ( (m) => m.matchString(setRefValue) ),
                ( (m) => 
                  if attribute.enum? then m.match(attribute.enum, setRefValue) 
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
  The Variable Predicate Provider
  ----------------
  Handles comparision of variables

  * _device_ is present
  * _device_ is not present
  * _device_ is absent
  ####
  class VariablePredicateProvider extends PredicateProvider

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      result = null
      allVariables = _(@framework.variableManager.variables).map( (v) => v.name ).valueOf()
      M(input, context)
        .matchNumericExpression(allVariables, (next, leftTokens) =>
          next.matchComparator('number', (next, comparator) =>
            next.matchNumericExpression(allVariables, (next, rightTokens) =>
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
      if @lastState? then return Q(@lastState)
      else return @_evaluate()
    destroy: -> 
      @framework.variableManager.removeListener("variableValueChanged", @changeListener)
      super()
    getType: -> 'state'

    _evaluate: ->
      leftPromise = @framework.variableManager.evaluateNumericExpression(@leftTokens)
      rightPromise = @framework.variableManager.evaluateNumericExpression(@rightTokens)
      return Q.all([leftPromise, rightPromise]).then( ([leftValue, rightValue]) =>
        return state = @_compareValues(leftValue, rightValue)
      )


    # ### _compareValues()
    ###
    Does the comparison.
    ###
    _compareValues: (left, right) ->
      return switch @comparator
        when '==' then left is right
        when '!=' then left isnt right
        when '<' then left < right
        when '>' then left > right
        when '<=' then left <= right
        when '>=' then left >= right
        else throw new Error "Unknown comparator: #{@comparator}"

  class ButtonPredicateProvider extends PredicateProvider

    _listener: {}

    constructor: (@framework) ->

    parsePredicate: (input, context) ->

      matchCount = 0
      matchingDevice = null
      matchingButtonId = null
      end = () => matchCount++
      onButtonMatch = (m, {device, buttonId}) =>
        matchingDevice = device
        matchingButtonId = buttonId

      buttonDevices = _(@framework.devices).values()
        .filter((d) => d instanceof env.devices.ButtonsDevice)

      buttonsWithId = buttonDevices
        .map( (d) => ( [{device: d, buttonId: b.id}, b.id] for b in d.config.buttons) )
        .flatten(true).valueOf()

      m = M(input, context)
        .match('the ', optional: true)
        .match(buttonsWithId, onButtonMatch)
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

    getValue: -> Q(false)
    destroy: -> 
      @device.removeListener 'button', @buttonPressedListener
      super()
    getType: -> 'event'

  return exports = {
    PredicateProvider
    PredicateHandler
    PresencePredicateProvider
    SwitchPredicateProvider
    DeviceAttributePredicateProvider
    VariablePredicateProvider
    ContactPredicateProvider
    ButtonPredicateProvider
  }