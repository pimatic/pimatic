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

  # ### canDecide()
  ###
  This function should return 'event' or 'state' if the sensor can decide the given predicate.
  If the sensor can decide the predicate and it is a event-predicate like 'its 10pm' then
  `canDecide` should return the string `'event'`
  If the provider can decide the predicate and it can be true or false like 'x is present' then 
  `canDecide` should return the string `'state'`
  If the sensor can not decide the given predicate then `canDecide` should return the boolean 
  `false`

  __params__

   * `predicate`: the predicate as string like `"its 10pm"` 
   * `context`: is used to add optional autocomplete hints or other hints
  ###
  canDecide: (predicate, context) ->
    throw new Error("your predicate provider must implement canDecide")

  # ### isTrue()
  ###
  The provider should return boolean `true` if the predicate is true and boolean `false` if it is 
  false. If the provider can not decide the predicate or the predicate is an event this function 
  should throw an Error.

  __params__

   * `id`: a string which is unique, can be ignored in most case. It could be used to cache the
     state of the predicate if it is difficult to decide.
   * `predicate` the predicate as string like `"x is present"` 
  ###
  isTrue: (id, predicate) ->
    throw new Error("your predicate provider must implement itTrue")

  # ### notifyWhen()
  ###
  The provider should call the given callback if the state of the predicate changes 
  (it becomes true or false). 
  The callback function takes one paramter which is the new state of the predicate. It should
  be boolean `true` if the predicate changed to true, it should be boolean `false` if the predicate 
  changed to false and if it is a event-predicate it should be the string `"event".
  If the provider can not decide the predicate this function should throw an Error.

  __params__

  * `id`: a string which is unique. It is to identify the requester so that the notify can be
     canceled by cancelNotify giving the same id later.
     state of the predicate if it is difficult to decide.
  * `predicate` the predicate as string like `"x is present"` 
  * `callback` the callback function to call with one parameter like noted above.
  ###
  notifyWhen: (id, predicate, callback) ->
    throw new Error("your predicate provider must implement notifyWhen")

  # ### cancelNotify()
  ###
  Cancels the notification for the predicate with the id given id.

  __params__
  
  * `id`: The unique string that was given at `notifyWhen`.
  ###
  cancelNotify: (id) ->
    throw new Error("your predicate provider must implement cancelNotify")

env = null

###
The Device-Event Predicate Provider
----------------
It's often the case that predicates depend on the value of a attribute of a device. If the value of
an attribute of a device changes an event is emitted that can be used to call the `notifyWhen` 
callback.

The `DeviceEventPredicateProvider` does handle the `canDecide`, `isTrue` and `cancleDecide`
function implementation. So there is only one function to be implemented by the sub class. This 
function is the `_parsePredicate` function witch gets the predicate to decide or notify and should
return a info object with some special keys. See the function description below for more details.
####
class DeviceEventPredicateProvider extends PredicateProvider
  _listener: {}

  # ### canDecide()
  ###
  Gets the info object from `_parsePredicate` implementation and checks if it returned null.
  ###
  canDecide: (predicate, context) ->
    info = @_parsePredicate predicate, context
    return if info? then 'state' else no 

  # ### isTrue()
  ###
  Gets the info object from `_parsePredicate` implementation and calls `getPredicateValue()` on it.
  ###
  isTrue: (id, predicate) ->
    info = @_parsePredicate predicate
    if info? then return info.getPredicateValue()
    else throw new Error "Can not decide \"#{predicate}\"!"


  # ### notifyWhen()
  ###
  Gets the `info` object from `_parsePredicate` implementation and registers an event listener 
  for `ìnfo.event` at `info.device`. The event listener is obtained by calling 
  `event.getEventListener`.
  ###
  notifyWhen: (id, predicate, callback) ->
    info = @_parsePredicate predicate
    if info?
      device = info.device
      event = info.event
      eventListener = info.getEventListener(callback)
      device.on event, eventListener
      @_listener[id] =
        id: id
        destroy: => device.removeListener event, eventListener
    else throw new Error "DeviceEventPredicateProvider can not decide \"#{predicate}\"!"

  # ### cancelNotify()
  ###
  Removes the notification for an with `notifyWhen` registered predicate. 
  ###
  cancelNotify: (id) ->
    listener = @_listener[id]
    if listener?
      listener.destroy()
    delete @_listener[id]

  # ### _parsePredicate()
  ###
  The `_parsePredicate` must be implemented by the subclass. It should parse the given predicate
  and return a `info` object at a match. If it does not match a predicate that the provider can
  handle then `null` sould be returned. The returned info object should have the following 
  properties:

  * info.event: the event of the device which triggers the `notifyWhen` callback
  * info.device: the device where the event which triggers the `notifyWhen` callback should be 
    registed
  * info.getEventListener: the event handler of the event. `getEventListener` gets the callack to
    call on change as a parameter.
  * info.getPredicateValue: the function that handles `isTrue`

  ###
  _parsePredicate: (predicate) ->
    throw new Error 'Should be implemented by supper class.'


###
The Switch Predicate Provider
----------------
Handles predicates for the state of switch devices like:

* _device_ is on|off
* _device_ is switched on|off
* _device_ is turned on|off

####
class SwitchPredicateProvider extends DeviceEventPredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  # ### _parsePredicate()
  ###
  Parses the string and setups the info object as explained in the DeviceEventPredicateProvider.
  Read the description of it to understand the return value.
  ###
  _parsePredicate: (predicate, context) ->  

    switchDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'state')).value()

    device = null
    state = null
    matchCount = 0
    M(predicate, context).matchDevice(switchDevices, (m, d) => device = d)
      .match([' is', ' is turned', ' is switched'])
      .match([' on', ' off'], (m, s) =>state = s)
      .onEnd( => matchCount++)

    # If we have a macht
    if matchCount is 1
      assert device?
      assert state?
      # and state as boolean.
      state = (state.trim() is "on")

      return info =
        device: device
        event: 'state'
        getPredicateValue: => 
          device.getAttributeValue('state').then (s) => s is state
        getEventListener: (callback) => 
          return eventListener = (s) => callback(s is state)
        state: state # for testing only
    else if matchCount > 1
      context.addError(""""#{predicate.trim()}" is ambiguous.""")
    return null

###
The Presence Predicate Provider
----------------
Handles predicates of presence devices like

* _device_ is present
* _device_ is not present
* _device_ is absent
####
class PresencePredicateProvider extends DeviceEventPredicateProvider

  constructor: (_env, @framework) ->
    env = _env

  # ### _parsePredicate()
  ###
  Parses the string and setups the info object as explained in the DeviceEventPredicateProvider.
  Read the description of it to understand the return value.
  ###
  _parsePredicate: (predicate, context) ->

    presenceDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'presence')).value()


    device = null
    state = null
    matchCount = 0
    M(predicate, context)
      .matchDevice(presenceDevices, (m, d) => device = d)
      .match([' is', ' reports', ' signals'])
      .match([' present', ' absent'], (m, s) => state = s)
      .onEnd( => matchCount++)

    if matchCount is 1
      assert device?
      assert state?

      negated = (state.trim() isnt "present") 

      return info =
        device: device
        event: 'presence'
        getPredicateValue: => 
          device.getAttributeValue('presence').then (presence) =>
            if negated then not presence else presence
        getEventListener: (callback) => 
          return eventListener = (presence) => 
            callback(if negated then not presence else presence)
        negated: negated # for testing only
    else if matchCount > 1
      context.addError(""""#{predicate.trim()}" is ambiguous.""")
    # If we have no match then return null.
    return null

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
class DeviceAttributePredicateProvider extends DeviceEventPredicateProvider

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

  # ### _parsePredicate()
  ###
  Parses the string and setups the info object as explained in the DeviceEventPredicateProvider.
  Read the description of it to understand the return value.
  ###
  _parsePredicate: (predicate, context) ->

    allAttributes = _(@framework.devices).values().map((device) => _.keys(device.attributes))
      .flatten().uniq().value()

    matchCount = 0
    info =
      device: null
      attributeName: null
      comparator: null
      referenceValue: null

    M(predicate, context)
    .match(allAttributes, (m, attr) =>
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
          m = m.match(possibleComparators, setComparator).matchNumber( (m,v) =>
            setRefValue(m, parseFloat(v))
          )
          m.onEnd(end)
          if attribute.unit? and attribute.unit.length > 0 
            possibleUnits = _.uniq([
              "#{attribute.unit}", 
              " #{attribute.unit}", 
              "#{attribute.unit.toLowerCase()}", 
              " #{attribute.unit.toLowerCase()}",
              "#{attribute.unit.replace('°', '')}", 
              " #{attribute.unit.replace('°', '')}",
              "#{attribute.unit.toLowerCase().replace('°', '')}", 
              " #{attribute.unit.toLowerCase().replace('°', '')}",
              ])
            m = m.match(possibleUnits)
        else if attribute.type is String
          m = m.match([' equals to ', ' is ', ' is not '], setComparator).matchString(setRefValue)
        m.onEnd(end)
      )
    )

    if matchCount is 1
      assert info.device?
      assert info.attributeName?
      assert info.comparator?
      assert info.referenceValue?

      found = false
      for sign, c of @comparators
        if info.comparator in c
          info.comparator = sign
          found = true
          break
      assert found
      device = info.device
      lastValue = null
      info.event = info.attributeName
      info.getPredicateValue = => 
        device.getAttributeValue(info.event).then (value) =>
          @_compareValues info.comparator, value, info.referenceValue
      info.getEventListener = (callback) => 
        return attributeListener = (value) =>
          state = @_compareValues info.comparator, value, info.referenceValue
          if state isnt lastValue
            lastValue = state
            callback state
      return info
    else if matchCount > 1
      context.addError(""""#{predicate.trim()}" is ambiguous.""")
    return null


module.exports.PredicateProvider = PredicateProvider
module.exports.PresencePredicateProvider = PresencePredicateProvider
module.exports.SwitchPredicateProvider = SwitchPredicateProvider
module.exports.DeviceAttributePredicateProvider = DeviceAttributePredicateProvider