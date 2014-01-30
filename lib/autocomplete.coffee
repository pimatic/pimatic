###
Autocomplete for bult in Predicates and Actions
=================
###

__ = require("i18n").__
Q = require 'q'
S = require 'string'
assert = require 'cassert'
_ = require 'lodash'


class Matcher

  constructor: (@inputs, @context) ->
    unless Array.isArray inputs then @inputs = [inputs]

  match: (patterns, callback = null) ->
    unless Array.isArray patterns then patterns = [patterns]
    rightParts = []

    for input in @inputs
      for p in patterns
        if typeof p is "string"
          if S(p).startsWith(input) and input.length < p.length
            @context.addHint(autocomplete: p)
        switch 
          when typeof p is "string" 
            doesMatch = S(input).startsWith(p)
            if doesMatch 
              match = p
              nextToken = S(input).chompLeft(p).s
          when p instanceof RegExp
            matches = input.match(p)
            if matches?
              doesMatch = yes
              match = matches[1]
              nextToken = matches[2]
          else throw new Error("Illegal object in patterns")
        if doesMatch
          if callback? then callback(new M(nextToken, @context), match)
          rightParts.push nextToken

    return new M(rightParts, @context)

  matchNumber: (callback) -> @match /^([0-9]+\.?[0-9]*)(.*)$/, callback

  matchString: (callback) -> 
    ret = M([], @context)
    @match('"').match(/^([^"]+)(.*)$/, (m, str) =>
      if str.length is 0 then @context.addHint(autocomplete: "")
      ret = m.match('"', callback)
    )
    return ret

  matchDevice: (devices, callback = null) ->
    unless Array.isArray devices then @devices = [devices]
    rightParts = []

    for input in @inputs
      for d in devices
        for p in [d.name, d.id]
          if S(p).startsWith(input) and input.length < p.length
            @context.addHint(autocomplete: p)
          if S(input).startsWith(p)
            nextToken = S(input).chompLeft(p).s
            if callback? then callback(new M(nextToken, @context), d)
            else rightParts.push nextToken

    unless callback? then return new M(rightParts, @context)

  onEnd: (callback) ->
    for input in @inputs
      if input.length is 0 then callback()

M = (args...) -> new Matcher(args...)



class SwitchPredicateAutocompleter

  constructor: (@framework) ->

  addHints: (predicate, context) ->
    switchDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'state')).value()
    M(predicate, context).matchDevice(switchDevices).match([' is']).match([' on', ' off'])

class PresencePredicateAutocompleter

  constructor: (@framework) ->

  addHints: (predicate, context) ->
    presenceDevices = _(@framework.devices).values()
      .filter((device) => device.hasAttribute( 'presence')).value()
    M(predicate, context).matchDevice(presenceDevices).match([' is']).match([' present', ' absent'])

class DeviceAttributePredicateAutocompleter

  constructor: (@framework) ->

  addHints: (predicate, context) ->

    allAttributes = _(@framework.devices).values().map((device) => _.keys(device.attributes))
      .flatten().uniq().value()
    M(predicate, context)
    .match(allAttributes, (m, attr) =>
      devices = _(@framework.devices).values().filter((device) => device.hasAttribute(attr)).value()
      m.match(' of ').matchDevice(devices, (m, device) =>
        attr = device.attributes[attr]
        if attr.type is Boolean
          m.match(' is ').match(attr.labels)
        else if attr.type is Number
          m.match( [' equals to ', ' is not ', ' is ', ' is less than ', ' is greater than '])
           .matchNumber().match("#{attr.unit}")
        else
          m.match([' equals to ', ' is ', ' is not '])
      )
    )

###
The Log Action Autocompleter
-------------
A helper that adds some autocomplete hints for the format of the log action. Just internal used
by the LogActionHandler to keep code clean and seperated.
###
class LogActionAutocompleter

  addHints: (actionString, context) ->
    stringToLog = null
    M(actionString, context).match("log ").matchString((m, str) =>
      stringToLog = str
    ).onEnd(->
      console.log "end log"
    )


###
The Switch Action Autocompleter
-------------
A helper that adds some autocomplete hints for the format of the switch action. Just internal used
by the SwitchActionHandler to keep code clean and seperated.
###
class SwitchActionAutocompleter 

  constructor: (@framework) ->

  addHints: (actionString, context) ->

    switchDevices = _(@framework.devices).values().filter( 
      (device) => device.hasAction("turnOn") and device.hasAction("turnOff") 
    ).value()

    m = M(actionString, context).match(['turn ', 'switch '])
    m.matchDevice(switchDevices).match([' on', ' off']).onEnd(->
      console.log "end 1"
    )
    m.match(['on ', 'off ']).matchDevice(switchDevices).onEnd(->
      console.log "end 2"
    )

module.exports.SwitchPredicateAutocompleter = SwitchPredicateAutocompleter
module.exports.PresencePredicateAutocompleter = PresencePredicateAutocompleter
module.exports.DeviceAttributePredicateAutocompleter = DeviceAttributePredicateAutocompleter

module.exports.LogActionAutocompleter = LogActionAutocompleter
module.exports.SwitchActionAutocompleter = SwitchActionAutocompleter