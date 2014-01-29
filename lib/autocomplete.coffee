###
Autocomplete for bult in Predicates and Actions
=================
###

__ = require("i18n").__
Q = require 'q'
S = require 'string'
assert = require 'cassert'
_ = require 'lodash'


class SwitchPredicateAutocompleter

  constructor: (@framework) ->

  addHints: (predicate, context) ->
    matches = predicate.match ///
      ^(.+?) # the device name
      (?:(\s+is?\s?)(o?n?|o?f?f?)$|$)
    ///
    console.log predicate, matches
    if predicate.length is 0 
      # autocomplete empty string with device names
      matches = ["",""]
    if matches?
      deviceName = matches[1]
      deviceNameLower = deviceName.toLowerCase()
      switchDevices = @_findAllSwitchDevices()
      deviceNameTrimed = deviceNameLower.trim()
      completeIs = matches[2]? and matches[2] is " is "
      for d in switchDevices
        # autocomplete name
        if S(d.name.toLowerCase()).startsWith(deviceNameLower)
          unless completeIs then context.addHint(autocomplete: "#{d.name} ")
        # autocomplete id
        if S(d.id.toLowerCase()).startsWith(deviceNameLower)
          unless completeIs then context.addHint(autocomplete: "#{d.id} ")
        # autocomplete name is
        if d.name.toLowerCase() is deviceNameTrimed or d.id.toLowerCase() is deviceNameTrimed
          unless completeIs then context.addHint(autocomplete: "#{deviceName.trim()} is")
          else context.addHint(autocomplete: ["#{deviceName.trim()} is on", 
            "#{deviceName.trim()} is off"])

  _findAllSwitchDevices: (context) ->
    # For all registed devices:
    matchingDevices = []
    for id, device of @framework.devices
      # check if the device has a state attribute
      if device.hasAttribute 'state'
        matchingDevices.push device
    return matchingDevices



class PresencePredicateAutocompleter

  constructor: (@framework) ->

  addHints: (predicate, context) ->
    matches = predicate.match ///
      ^(.+?) # the device name
      (\s+is\s*)?$ # followed by whitespace
    ///
    if predicate.length is 0 
      # autocomplete empty string with device names
      matches = ["",""]
    if matches?
      deviceNameLower = matches[1].toLowerCase()
      switchDevices = @_findAllSwitchDevices()
      deviceNameTrimed = deviceNameLower.trim()
      for d in switchDevices
        # autocomplete name
        if d.name.toLowerCase().indexOf(deviceNameLower) is 0
          unless matches[2]? then context.addHint(autocomplete: "#{d.name} ")
        # autocomplete id
        if d.id.toLowerCase().indexOf(deviceNameLower) is 0
          unless matches[2]? then context.addHint(autocomplete: "#{d.id} ")
        # autocomplete name is
        if d.name.toLowerCase() is deviceNameTrimed or d.id.toLowerCase() is deviceNameTrimed
          unless matches[2]? then context.addHint(autocomplete: "#{predicate.trim()} is")
          else context.addHint(autocomplete: [
            "#{predicate.trim()} present", 
            "#{predicate.trim()} absent"
          ])

  _findAllSwitchDevices: (context) ->
    # For all registed devices:
    matchingDevices = []
    for id, device of @framework.devices
      # check if the device has a state attribute
      if device.hasAttribute 'presence'
        matchingDevices.push device
    return matchingDevices


class DeviceAttributePredicateAutocompleter

  constructor: (@framework) ->


  _partlyMatchPredicate: (predicate) ->
    match = predicate.match ///
      ^(.*?)
       (?:(\so?f?\s?)
          (?:(.*?)
             (?:(?:(?:\s(
                e?q?u?a?l?s?|
                i?s?\s?n?o?t?|
                i?s?\s?l?e?s?s?\s?t?h?a?n?|
                i?s?\s?g?r?e?a?t?e?r?\s?t?h?a?n?|
                i?s?))
                (?:\s(.*?)$
              |$))
            $|$)
          |$)
        |$)
    ///
    return {
      attribute: match[1]
      of: match[2]
      device: match[3]
      comparator: match[4]
      valueAndUnit: match[5]
    }



  addHints: (predicate, context) ->

    startsWith = (str, prefix) -> str.indexOf(prefix) is 0
    endsWith = (str, suffix) -> str.lastIndexOf(suffix) is str.length - suffix.length

    getAllPossibleAttributes = () =>
      return _.uniq(
        _.reduce(d for i,d of @framework.devices, (result, device) => 
          result.concat (name for name of device.attributes)
        , [])
      )

    getAllPossibleDevices = (attribute) =>
      return _.filter(d for i,d of @framework.devices, (d) => 
        d.hasAttribute attribute
      )

    matchesAttribute = (attributes, str) => _.filter(attributes, (a)=>startsWith(a, str.trim()))
    matchesDevice = (devices, str) => _.filter(devices, (d) =>
      startsWith(d.name, str.trim()) or startsWith(d.id, str.trim())
    ) 

    matches = @_partlyMatchPredicate(predicate)
    console.log matches
    unless matches.attribute? then return

    attributes = getAllPossibleAttributes()
    matchingAttributes = matchesAttribute(attributes, matches.attribute)

    if matchingAttributes.length is 0 then return
    
    unless matches.of?
      context.addHint(autocomplete: _.map(matchingAttributes, (a)=>"#{a} of "))
      return

    possibleDevices = getAllPossibleDevices(matches.attribute)
    matchingDevices = matchesDevice(possibleDevices, matches.device)

    matchingDevice = _.first _.filter(matchingDevices, (d)=> 
      d.name is matches.device.trim() or d.id is matches.device.trim()
    )

    unless matchingDevice?
      context.addHint(autocomplete: _.map(matchingDevices, (d)=>"#{matches.attribute} of #{d.id} "))
      context.addHint(autocomplete: _.map(matchingDevices, (d) => 
        "#{matches.attribute} of #{d.name} "
      ))
      return
    prefix = "#{matches.attribute}"

    matchingDevice = matchingDevices[0]
    # check if the attribut is numeric
    attributeType = matchingDevice.attributes[matches.attribute].type
    prefix = "#{prefix} of #{matches.device.trim()}"

    if matches.comparator?
      prefixes = ['equals to', 'is not', 'is', 'is less than', 'is greater than']
      matchingPrefixes = _.filter(prefixes, (c) => startsWith(c, matches.comparator))
      if matchingPrefixes.length > 0
        if attributeType is Number
          context.addHint(
            autocomplete: _.map(
              matchingPrefixes
              , (comparator) => "#{prefix} #{comparator} "
            )
          )
        else if attributeType is Boolean
          labels = matchingDevice.attributes[matches.attribute].labels
          context.addHint(
            autocomplete: _.map(labels,
              (label) => "#{prefix} is #{label}"
            )
          )
        else 
          context.addHint(
            # todo cut with matchingPrefixes
            autocomplete: _.map(['equals to', 'is', 'is not'],
              (comparator) => "#{prefix} #{comparator} "
            )
          )

    prefix = "#{prefix} #{matches.comparator} #{matches.valueAndUnit}"
    if matches.valueAndUnit? and attributeType is Number and matches.valueAndUnit.length > 0 and 
    not isNaN(matches.valueAndUnit)
      unit = matchingDevice.attributes[matches.attribute].unit 
      if unit?
        context.addHint(autocomplete: "#{prefix}#{unit}")

###
The Log Action Autocompleter
-------------
A helper that adds some autocomplete hints for the format of the log action. Just internal used
by the LogActionHandler to keep code clean and seperated.
###
class LogActionAutocompleter

  addHints: (actionString, context) ->
    # If the string is a prefix of log
    if "log \"".indexOf(actionString) is 0
      # then we could autcomplete to "log "
      context.addHint(
        autocomplete: "log \""
      )
    # if it stats with "log \"some text" then we can autocomplete to
    # "log \"some text\"" 
    else if actionString.match /log\s+"[^"]+$/
      context.addHint(
        autocomplete: actionString + '"'
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
    # autcomplete empty string
    firstWord = _.filter(["switch", "turn"], (s) => S(s).startsWith(actionString) )
    switchDevices = @_findAllSwitchDevices()

    if firstWord.length > 0
        context.addHint(
          autocomplete: _.map(firstWord, (w) => "#{w} ")
        )
    else 
      # autocomplete turn|switch some-device
      match = actionString.match ///^(turn|switch) # Must begin with "turn" or "switch"
        \s+ #followed by whitespace
        (.*?)(?:\s(o?n?|o?f?f?)$|$)
      ///
      if match?
        prefix = match[1]
        deviceName = match[2]
        deviceNameLower = deviceName.toLowerCase()
        deviceNameTrimed = deviceNameLower.trim()
        switchDevices = @_findAllSwitchDevices()

        for d in switchDevices
          # autocomplete name
          if S(d.name.toLowerCase()).startsWith(deviceNameLower)
            context.addHint(
              autocomplete: "#{prefix} #{d.name} " 
            )
          # autocomplete id
          if S(d.id.toLowerCase()).startsWith(deviceNameLower)
            context.addHint(
              autocomplete: "#{prefix} #{d.id} " 
            )
          # autocomplete name od id and on off
          if d.name.toLowerCase() is deviceNameTrimed or d.id.toLowerCase() is deviceNameTrimed
            context.addHint(
              autocomplete: ["#{prefix} #{deviceName.trim()} on", 
                "#{prefix} #{deviceName.trim()} off"]
            )

  _findAllSwitchDevices: () ->
    # For all registed devices:
    matchingDevices = []
    for id, device of @framework.devices
      # and the device has the "turnOn" or "turnOff" action
      if device.hasAction("turnOn") or device.hasAction("turnOff") 
        # then simulate or do the action.
        matchingDevices.push device
    return matchingDevices


module.exports.SwitchPredicateAutocompleter = SwitchPredicateAutocompleter
module.exports.PresencePredicateAutocompleter = PresencePredicateAutocompleter
module.exports.DeviceAttributePredicateAutocompleter = DeviceAttributePredicateAutocompleter

module.exports.LogActionAutocompleter = LogActionAutocompleter
module.exports.SwitchActionAutocompleter = SwitchActionAutocompleter