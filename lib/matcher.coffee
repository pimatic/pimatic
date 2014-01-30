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

  constructor: (@inputs, @context) ->
    unless Array.isArray inputs then @inputs = [inputs]

  match: (patterns, callback = null) ->
    unless Array.isArray patterns then patterns = [patterns]
    rightParts = []

    for input in @inputs
      for p in patterns
        if typeof p is "string" and @context?
          if S(p).startsWith(input) and input.length < p.length
            @context.addHint(autocomplete: p)
        doesMatch = false
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

  matchNumber: (callback) -> @match /^([0-9]+\.?[0-9]*)(.*?)$/, callback

  matchString: (callback) -> 
    ret = M([], @context)
    @match('"').match(/^([^"]+)(.*?)$/, (m, str) =>
      m.onEnd( => @context.addHint(autocomplete: ""))
      ret = m.match('"', (m) => 
        callback(m, str)
      )
    )
    return ret

  matchDevice: (devices, callback = null) ->
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
        if S(input.toLowerCase()).startsWith(d.id)
          nextTokenId = input.substring(d.id.length, input.length)
          if callback? then callback(new M(nextTokenId, @context), d)
          rightParts.push nextTokenId
        
        # try to match the name case insensitive and ignoring 'the ' prefix
        inputTmp = S(input).toLowerCase()
        if inputTmp.startsWith('the ')
          inputTmp = inputTmp.substring('the '.length, inputTmp.length)
        nameTmp = S(d.name).toLowerCase()
        if nameTmp.startsWith('the ')
          nameTmp = nameTmp.substring('the '.length, nameTmp.length)
        if inputTmp.startsWith(nameTmp)
          prefixSize = input.length - inputTmp.length + nameTmp.length
          nextTokenName = input.substring(prefixSize, input.size)
          # Don't call again with the same next token
          unless nextTokenName is nextTokenId
            if callback? then callback(new M(nextTokenName, @context), d)
            rightParts.push nextTokenName

    return new M(rightParts, @context)

  onEnd: (callback) ->
    for input in @inputs
      if input.length is 0 then callback()

M = (args...) -> new Matcher(args...)

module.exports = M