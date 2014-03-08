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


###
The Predicate Provider
----------------
This is the base class for all predicate provider. 
###
class PredicateProvider

  parsePredicate: (input, context) -> throw new Error("You must implement parsePredicate")

env = null


class PredicateHandler extends require('events').EventEmitter

  getType: -> throw new Error("You must implement getType")
  getValue: -> throw new Error("You must implement getState")
  destroy: ->  throw new Error("You must implement destroy")

###
The Switch Predicate Provider
----------------
Provides predicates for the state of switch devices like:

* _device_ is on|off
* _device_ is switched on|off
* _device_ is turned on|off

####
class SwitchPredicateProvider extends PredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  # ### parsePredicate()
  parsePredicate: (input, context) ->  

    switchDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'state')).value()

    device = null
    state = null

    setDevice = (m, d) => device = d
    setState = (m, s) => state = s
    stateAcFilter = (v) => v.trim() isnt 'is switched' 

    m = M(input, context)
      .matchDevice(switchDevices, setDevice)
      .match([' is', ' is turned', ' is switched'], acFilter: stateAcFilter)
      .match([' on', ' off'], setState)

    matchCount = m.getMatchCount()

    # If we have a macht
    if matchCount is 1
      match = m.getFullMatches()[0]
      assert device?
      assert state?
      # and state as boolean.
      state = (state.trim() is "on")

      context?.addMatch(match)

      return {
        token: match
        nextInput: m.inputs[0]
        predicateHandler: new SwitchPredicateHandler(device, state)
      }

    else if matchCount > 1
      context?.addError(""""#{input.trim()}" is ambiguous.""")
    return null

class SwitchPredicateHandler extends PredicateHandler

  constructor: (@device, @state) ->
    @stateListener = (s) => @emit 'change', (s is @state)
    @device.on 'state', @stateListener
  getValue: -> @device.getAttributeValue('state').then( (s) => (s is @state) )
  destroy: -> @device.removeListener "state", @stateListener
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

  constructor: (_env, @framework) ->
    env = _env


  parsePredicate: (input, context) ->

    presenceDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'presence')).value()

    device = null
    state = null

    setDevice = (m, d) => device = d
    setState =  (m, s) => state = s
    stateAcFilter = (v) => v.trim() isnt 'not present'

    m = M(input, context)
      .matchDevice(presenceDevices, setDevice)
      .match([' is', ' reports', ' signals'])
      .match([' present', ' absent', ' not present'], {acFilter: stateAcFilter}, setState)

    matchCount = m.getMatchCount()

    if matchCount is 1
      match = m.getFullMatches()[0]
      assert device?
      assert state?

      negated = (state.trim() isnt "present") 

      context?.addMatch(match)

      return {
        token: match
        nextInput: m.inputs[0]
        predicateHandler: new PresencePredicateHandler(device, negated)
      }
      
    else if matchCount > 1
      context?.addError(""""#{input.trim()}" is ambiguous.""")
    # If we have no match then return null.
    return null

class PresencePredicateHandler extends PredicateHandler

  constructor: (@device, @negated) ->
    @presenceListener = (p) => 
      @emit 'change', (if @negated then not p else p)
    @device.on 'presence', @presenceListener
  getValue: -> @device.getAttributeValue('presence').then( (p) => (if @negated then not p else p) )
  destroy: -> @device.removeListener "presence", @presenceListener
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

  constructor: (_env, @framework) ->
    env = _env

    @comparators =
    '==': ['equals', 'is equal to', 'is equal', 'is']
    '!=': [ 'is not' ]
    '<': ['less', 'lower', 'below']
    '>': ['greater', 'higher', 'above']

    for sign in ['<', '>']
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
      devices = _(@framework.devices).values().filter((device) => device.hasAttribute(attr)).value()
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
            v.trim() in ['is', 'is not', 'equals', 'is greater than', 'is less than']
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
            if result.device.id isnt info.device.id or result.attributeName isnt info.attributeName
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

      context?.addMatch(match)

      found = false
      for sign, c of @comparators
        if result.comparator in c
          result.comparator = sign
          found = true
          break
      assert found

      return {
        token: match
        nextInput: S(predicate).chompLeft(match).s
        predicateHandler: new DeviceAttributePredicateHandler(
          result.device, result.attributeName, result.comparator, result.referenceValue
        )
      }
      
    return null


class DeviceAttributePredicateHandler extends PredicateHandler

  constructor: (@device, @attribute, @comparator, @referenceValue) ->
    lastState = null
    @attributeListener = (value) =>
      state = @_compareValues(@comparator, value, @referenceValue)
      if state isnt lastState
        lastState = state
        @emit 'change', state
    @device.on @attribute, @attributeListener
  getValue: -> 
    @device.getAttributeValue(@attribute).then( (value) =>
      @_compareValues(@comparator, value, @referenceValue)
    )
  destroy: -> @device.removeListener @attribute, @attributeListener
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
      else throw new Error "Unknown comparator: #{comparator}"

module.exports.PredicateProvider = PredicateProvider
module.exports.PredicateHandler = PredicateHandler
module.exports.PresencePredicateProvider = PresencePredicateProvider
module.exports.SwitchPredicateProvider = SwitchPredicateProvider
module.exports.DeviceAttributePredicateProvider = DeviceAttributePredicateProvider