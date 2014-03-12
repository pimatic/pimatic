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
    getValue: -> throw new Error("You must implement getState")

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
              match = next.getFullMatches()[0]
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
    getValue: -> @device.getAttributeValue('state').then( (s) => (s is @state) )
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
              match = m.getFullMatches()[0]
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
    getValue: -> @device.getAttributeValue('presence').then((p) => (if @negated then not p else p))
    destroy: -> 
      @device.removeListener "presence", @presenceListener
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

      @comparators =
      '==': ['equals', 'is equal to', 'is equal', 'is']
      '!=': [ 'is not' ]
      '<': ['less', 'lower', 'below']
      '>': ['greater', 'higher', 'above']
      '>=': ['greater or equal', 'higher or equal', 'above or equal',
            'equal or greater', 'equal or higher', 'equal or above']
      '<=': ['less or equal', 'lower or equal', 'below or equal',
            'equal or less', 'equal or lower', 'equal or below']

      for sign in ['<', '>', '<=', '>=']
        @comparators[sign] = _(@comparators[sign]).map( 
          (c) => [c, "is #{c}", "is #{c} than", "is #{c} as", "#{c} than", "#{c} as"]
        ).flatten().value()



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

          setComparator =  (m, c) => info.comparator = c.trim()
          setRefValue = (m, v) => info.referenceValue = v
          end =  => matchCount++

          if attribute.type is Boolean
            m = m.match(' is ', setComparator).match(attribute.labels, setRefValue)
          else if attribute.type is Number
            possibleComparators = _(@comparators).values().flatten().map((c)=>" #{c} ").value()
            autocompleteFilter = (v) => 
              v.trim() in ['is', 'is not', 'equals', 'is greater than', 'is less than', 
                'is greater or equal than', 'is less or equal than']
            m = m.match(possibleComparators, acFilter: autocompleteFilter, setComparator)
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
          else if attribute.type is String
            m = m.match([' equals to ', ' is ', ' is not '], setComparator).matchString(setRefValue)
          else if Array.isArray attribute.type
            m = m.match([' equals to ', ' is ', ' is not '], setComparator)
              .match(attribute.type, setRefValue) 
          if m.getMatchCount() > 0 
            matches = matches.concat m.getFullMatches()
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

        found = false
        for sign, c of @comparators
          if result.comparator in c
            result.comparator = sign
            found = true
            break
        assert found
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
      @device.getAttributeValue(@attribute).then( (value) =>
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
      unless isNaN value
        value = parseFloat value
      return switch comparator
        when '==' then value is referenceValue
        when '!=' then value isnt referenceValue
        when '<' then value < referenceValue
        when '>' then value > referenceValue
        when '<=' then value <= referenceValue
        when '>=' then value >= referenceValue
        else throw new Error "Unknown comparator: #{comparator}"

  return exports = {
    PredicateProvider
    PredicateHandler
    PresencePredicateProvider
    SwitchPredicateProvider
    DeviceAttributePredicateProvider
  }