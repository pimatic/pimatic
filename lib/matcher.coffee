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
      for p, i in patterns
        # If pattern is a array then assume that first element is an id that should be returned
        # on match
        matchId = null
        if Array.isArray p
          assert p.length is 2
          [matchId, p] = p

        # handle ignore case for string
        [pT, inputT] = (
          if options.ignoreCase and typeof p is "string"
            [p.toLowerCase(), input.toLowerCase()]
          else
            [p, input]
        )

        # if pattern is an string, then we cann add an autocomplete for it
        if typeof p is "string" and @context
          showAc = (if options.acFilter? then options.acFilter(p, i) else true) 
          if showAc
            if S(pT).startsWith(inputT) and input.length < p.length
              @context.addHint(autocomplete: p)

        # Now try to match the pattern against the input string
        doesMatch = false
        switch 
          # do a normal string match
          when typeof p is "string" 
            doesMatch = S(inputT).startsWith(pT)
            if doesMatch 
              match = p
              nextToken = input.substring(p.length)
          # do a regax match
          when p instanceof RegExp
            if options.ignoreCase?
              throw new new Error("ignoreCase option can't be used with regexp")
            regexpMatch = input.match(p)
            if regexpMatch?
              doesMatch = yes
              match = regexpMatch[1]
              nextToken = regexpMatch[2]
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

    return M(rightParts, @context)

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
    devices = _(devices).clone()
    devicesWithId = _(devices).map( (d) => [d, d.id] ).value()
    m = @match('the ', optional: true)
    # first try to match by id
    m.match(devicesWithId, (m, d) => 
      callback(m, d)
      #if it matches here we remove it from the array so it don't 
      # get matched twice
      _(devices).remove(d)
    )
    # then to try match names
    devicesWithNames = _(devices).map( (d) => [d, d.name] ).value() 
    m.match(devicesWithNames, ignoreCase: yes, callback)

  # ###onEnd()
  ###
  The given callback will be called for every empty string in the inputs of ther current matcher
  ###
  onEnd: (callback) ->
    for input in @inputs
      if input.length is 0 then callback()

  inAnyOrder: (callbacks) ->
    assert Array.isArray callbacks
    hadMatch = yes
    current = this
    while hadMatch
      hadMatch = no
      for next in callbacks
        assert typeof next is "function"
        # try to match with this matcher
        m = next(current)
        assert m instanceof Matcher
        unless m.hadNoMatches()
          hadMatch = yes
          current = m
    return current

  or: (callbacks) ->
    assert Array.isArray callbacks
    ms = (
      for next in callbacks
        m = next(this)
        assert m instanceof Matcher
        m
    )
    # join all inputs together
    newInputs = _(ms).map((m)=>m.inputs).flatten().value()
    return M(newInputs, @context)

    
  hadNoMatches: -> inputs.length is 0

M = (args...) -> new Matcher(args...)

module.exports = M
module.exports.Matcher = Matcher