###
Matcher/Parser helper for predicate and action strings
=================
###

__ = require("i18n").__
Q = require 'q'
S = require 'string'
assert = require 'cassert'
_ = require 'lodash'


class Matcher
  # ###constructor()
  # Create a matcher for the input string, with the given parse context
  constructor: (@inputs, @context) ->
    unless Array.isArray inputs then @inputs = [inputs]
  
  # ###match()
  ###
  Matches the current inputs against the given pattern
  pattern can be an string, an regexp or an array of strings or regexps.
  If a callback is given it is called with a new Matcher for the remaining part of the string
  and the matching part of the input
  In addition a matcher is returned that hast the remaining parts as input.
  ###
  match: (patterns, options = {}, callback = null) ->
    unless Array.isArray patterns then patterns = [patterns]
    if typeof options is "function"
      callback = options
      options = {}

    matches = {}
    rightParts = []

    for input in @inputs
      for p in patterns
        # If pattern is a array then assume that first element is an id that should be returned
        # on match
        matchId = null
        if Array.isArray p
          assert p.length is 2
          [matchId, p] = p
        # if pattern is an string, then we cann add an autocomplete for it
        if typeof p is "string" and @context?
          if S(p).startsWith(input) and input.length < p.length
            @context.addHint(autocomplete: p)

        # Now try to match the pattern against the input string
        doesMatch = false
        switch 
          # do a normal string match
          when typeof p is "string" 
            doesMatch = S(input).startsWith(p)
            if doesMatch 
              match = p
              nextToken = S(input).chompLeft(p).s
          # do a regax match
          when p instanceof RegExp
            matches = input.match(p)
            if matches?
              doesMatch = yes
              match = matches[1]
              nextToken = matches[2]
          else throw new Error("Illegal object in patterns")

        if doesMatch and not matches[match]?
          matches[match] = yes
          # If no matchId was provided then use the matching string itself
          unless matchId? then matchId = match
          if callback? then callback(new M(nextToken, @context), matchId)
          rightParts.push nextToken
        else if options.optional and not matches['']?
          matches[''] = yes
          rightParts.push input

    return new M(rightParts, @context)

  # ###matchNumber()
  ###
  Matches any Number.
  ###
  matchNumber: (callback) -> @match /^([0-9]+\.?[0-9]*)(.*?)$/, callback

  matchString: (callback) -> 
    ret = M([], @context)
    @match('"').match(/^([^"]+)(.*?)$/, (m, str) =>
      ret = m.match('"', (m) => 
        callback(m, str)
      )
    )
    return ret

  # ###matchDevice()
  ###
  Matches any of the given devices.
  ###
  matchDevice: (devices, callback = null) ->
    @match('the ', optional: true)._matchDevice(devices, callback)

  _matchDevice: (devices, callback = null) ->
    unless Array.isArray devices then @devices = [devices]
    rightParts = []

    for input in @inputs
      for d in devices
        # add autcompletes
        for p in [d.name, d.id]
          if S(p).startsWith(input) and input.length < p.length
            @context.addHint(autocomplete: p)

        nextTokenId = null
        # try to exactly case insensitive match the id
        if S(input.toLowerCase()).startsWith(d.id.toLowerCase())
          nextTokenId = input.substring(d.id.length, input.length)
          if callback? then callback(new M(nextTokenId, @context), d)
          rightParts.push nextTokenId

        # try to case insensitive match the name
        if S(input.toLowerCase()).startsWith(d.name.toLowerCase())
          nextTokenName = input.substring(d.name.length, input.length)
          unless nextTokenName is nextTokenId
            if callback? then callback(new M(nextTokenName, @context), d)
            rightParts.push nextTokenName

    return new M(rightParts, @context)

  # ###onEnd()
  ###
  The given callback will be called for every empty string in the inputs of ther current matcher
  ###
  onEnd: (callback) ->
    for input in @inputs
      if input.length is 0 then callback()

M = (args...) -> new Matcher(args...)

module.exports = M
module.exports.Matcher = Matcher