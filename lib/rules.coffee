assert = require 'cassert'
logger = require "./logger"

class RuleManager extends require('events').EventEmitter
  rules: []
  server: null
  actionHandlers: []

  constructor: (@server) ->

  findSensorForPredicate: (id, predicate, callback) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert predicate? and typeof predicate is "string" and predicate.length isnt 0
    assert callback? and typeof callback is "function"

    for sensorId, sensor of @server.sensors
      if sensor.notifyWhen id, predicate, callback
        return sensor
    return null

  predicateIsTrue: (ruleId, predicateId) ->
    assert ruleId? and typeof ruleId is "string" and ruleId.length isnt 0
    assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0

    knownTruePredicates = []
    knownTruePredicates.push predicateId
    rule = @rules[ruleId]
    trueOrFalse = @evaluateConditionOfRule rule, knownTruePredicates
    if trueOrFalse then @executeAction rule.action, false, (e, message)->
      logger.error "Rule #{ruleId} error: #{e}" if e?
      logger.info "Rule #{ruleId}: #{message}" if message?

  parseRuleString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    _this = this
    # * First take the string apart:
    parts = ruleString.split /^if\s|\sthen\s/
    # * => parts should now be `["", "the if part", "the then part"]`
    switch
      when parts.length < 3 
        throw new Error('The rule must start with "if" and contain a "then" part!')
      when parts.length > 3 
        throw new Error('The rule must exactly contain one "if" and one "then"!')
    condition = parts[1].trim()
    actions = parts[2].trim()

    # Split the condition in a token stream.
    # For example: "12:30 and temperature > 10" becomes
    # `['12:30', 'and', 'temperature > 30 C']`
    # Then we replace all predicates throw predicate tokens:
    # `['predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')']`
    # and remember the predicates in predicates
    # `predicates = [ {token: '12:30'}, {token: 'temperature > 10'}]`
    predicates = []
    tokens = []
    for token in condition.split /(\sand\s|\sor\s|\)|\()/ 
      do (token) ->
        token = token.trim()
        if token in ["and", "or", ")", "("]
          tokens.push token
        else
          i = predicates.length
          predId = id+i
          predSensor =  _this.findSensorForPredicate predId, token, ->
            _this.predicateIsTrue id, predId

          predicate =
            id: predId
            token: token
            sensor: predSensor

          if predicate.sensor?
            predicates.push(predicate)
            tokens = tokens.concat ["predicate", "(", i, ")"]
          else
            p.sensor.cancelNotify p.id for p in predicates
            throw new Error "Could not found an sensor that decides \"#{predicate.token}\""
    
    # Ok now the easier part: the action
    ok = _this.executeAction actions, true, -> 
    if not ok then throw Error "Could not find a actuator to execute \"#{actions}\""

    return rule = 
      id: id
      orgCondition: condition
      predicates: predicates
      tokens: tokens
      action: actions
      string: ruleString

  addRuleByString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    # * Parse the rule to ower rules array
    @rules[id] = rule = @parseRuleString id, ruleString
    @emit "add", rule

    # Check if the condition of the rule is allready true
    trueOrFalse = @evaluateConditionOfRule @rules[id]
    if trueOrFalse then @executeAction actions, false, (e, message)->
      logger.error "Rule #{ruleId} error: #{e}" if e?
      logger.info "Rule #{ruleId}: #{message}" if message?

  removeRule: (id) ->
    assert id? and typeof id is "string" and id.length isnt 0
    throw new Error("Invalid ruleId: \"#{ruleId}\"") unless @rules[id]?
    rule = @rules[id]
    # * Then cancel all Notifier for all predicates
    p.sensor.cancelNotify p.id for p in rule.predicates
    delete @rules[id]
    @emit "remove", rule

  updateRuleByString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    throw new Error("Invalid ruleId: \"#{ruleId}\"") unless @rules[id]?
    # * First try to parse the updated ruleString:
    rule = @parseRuleString id, ruleString
    oldRule = @rules[id]
    # * Then cancel all Notifier for all predicates
    p.sensor.cancelNotify p.id for p in oldRule.predicates
    # * Add the rule to the rules
    @rules[id] = rule
    @emit "update", rule
    # * Check if the condition of the rule is allready true and execute the actions
    trueOrFalse = @evaluateConditionOfRule rule
    if trueOrFalse then @executeAction rule.actions, false, (e, message)->
      logger.error "Rule #{ruleId} error: #{e}" if e?
      logger.info "Rule #{ruleId}: #{message}" if message?

  # Uses 'bet' to evaluate rule.tokens
  evaluateConditionOfRule: (rule, knownTruePredicates = []) ->
    assert rule? and rule instanceof Object
    assert Array.isArray knownTruePredicates

    bet = require 'bet'
    bet.operators['and'] =
      assoc: 'left'
      prec: 0
      argc: 2
      fix: 'in'
      exec: (args) -> if args[0] isnt 0 and args[1] isnt 0 then 1 else 0
    bet.operators['or'] =
      assoc: 'left'
      prec: 1
      argc: 2
      fix: 'in'
      exec: (args) -> if args[0] isnt 0 or args[1] isnt 0 then 1 else 0
    bet.functions['predicate'] =
    argc: 1
    exec: (args) ->
      predicate = rule.predicates[args[0]]
      if predicate.id in knownTruePredicates
        trueOrFalse = true
      else
        trueOrFalse = predicate.sensor.isTrue predicate.id, predicate.token
      return if trueOrFalse then 1 else 0

    #console.log rule.tokens
    return bet.evaluateSync rule.tokens

  executeAction: (actionString, simulate, callback) ->
    assert actionString? and typeof actionString is "string" 
    assert simulate? and typeof simulate is "boolean"
    assert callback? and typeof callback is "function"

    for aH in @actionHandlers
      actionFunc = aH.executeAction actionString, simulate, callback
      if actionFunc?
        actionFunc()
        return true
      else
        return false

module.exports.RuleManager = RuleManager