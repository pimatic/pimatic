assert = require 'cassert'
logger = require "./logger"
util = require 'util'
Q = require 'q'

class RuleManager extends require('events').EventEmitter
  rules: []
  server: null
  actionHandlers: []

  constructor: (@server) ->

  findSensorForPredicate: (predicate) ->
    assert predicate? and typeof predicate is "string" and predicate.length isnt 0

    for sensorId, sensor of @server.sensors
      if sensor.canDecide predicate
        return sensor
    return null

  whenPredicateIsTrue: (ruleId, predicateId) ->
    self = this
    assert ruleId? and typeof ruleId is "string" and ruleId.length isnt 0
    assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0

    knownTruePredicates = [predicateId]
    rule = self.rules[ruleId]

    self.evaluateConditionOfRule(rule, knownTruePredicates).then( (isTrue) ->
      if isTrue then self.executeAction(rule.action, false).then( (message) ->
        logger.info "Rule #{ruleId}: #{message}"
      ).catch( (error)->
        logger.error "Rule #{ruleId} error: #{error}"
      ).done()
    )
    return


  parseRuleString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    self = this
    return Q.fcall ->
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
            predSensor = self.findSensorForPredicate token

            predicate =
              id: predId
              token: token
              sensor: predSensor

            if not predicate.sensor?
              throw new Error "Could not find an sensor that decides \"#{predicate.token}\""

            predicates.push(predicate)
            tokens = tokens.concat ["predicate", "(", i, ")"]
              
      # Register all sensors:
      for p in predicates
        p.sensor.notifyWhen p.id, p.token, ->
          self.whenPredicateIsTrue id, p.id

      # Ok now the easier part: the action
      return self.executeAction(actions, true).then( ->
        return rule = 
          id: id
          orgCondition: condition
          predicates: predicates
          tokens: tokens
          action: actions
          string: ruleString

      ).catch( (error) ->
        logger.debug error
        throw new Error "Could not find a actuator to execute \"#{actions}\""
      )

  addRuleByString: (id, ruleString) ->
    self = this
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    # * Parse the rule to ower rules array
    return self.parseRuleString(id, ruleString).then( (rule)->
      self.rules[id] = rule
      self.emit "add", rule
      # Check if the condition of the rule is allready true
      self.evaluateConditionOfRule(rule).then( (isTrue) ->
        if isTrue then self.executeAction(rule.action, false).then( (message) ->
          logger.info "Rule #{ruleId}: #{message}"
        ).catch( (error)->
          logger.error "Rule #{ruleId} error: #{error}"
        )
      )
    )

  removeRule: (id) ->
    assert id? and typeof id is "string" and id.length isnt 0
    throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?
    rule = @rules[id]
    # * Then cancel all Notifier for all predicates
    p.sensor.cancelNotify p.id for p in rule.predicates
    delete @rules[id]
    @emit "remove", rule

  updateRuleByString: (id, ruleString) ->
    self = this
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"
    throw new Error("Invalid ruleId: \"#{id}\"") unless self.rules[id]?

    # * First try to parse the updated ruleString:
    return self.parseRuleString(id, ruleString).then( (rule)->
      oldRule = self.rules[id]
      # * Then cancel all Notifier for all predicates
      p.sensor.cancelNotify p.id for p in oldRule.predicates
      # * Add the rule to the rules
      self.rules[id] = rule
      self.emit "update", rule
      # * Check if the condition of the rule is allready true and execute the actions
      return self.evaluateConditionOfRule(rule).then( (isTrue) ->
        if isTrue then self.executeAction(rule.action, false).then( (message) ->
          logger.info "Rule #{id}: #{message}"
        ).catch( (error)->
          logger.error "Rule #{id} error: #{error}"
        )
      )
    )


  # Uses 'bet' to evaluate rule.tokens
  evaluateConditionOfRule: (rule, knownTruePredicates = []) ->
    assert rule? and rule instanceof Object
    assert Array.isArray knownTruePredicates

    predicateValues = []
    for pred in rule.predicates
      if pred.id in knownTruePredicates
        predicateValues.push (Q.fcall -> true)
      else
        predicateValues.push (pred.sensor.isTrue pred.id, pred.token)

    return Q.all(predicateValues).then( (predicateValues) ->
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
      exec: (args) -> if predicateValues[args[0]] then 1 else 0

      return bet.evaluateSync rule.tokens
    )

  executeAction: (actionString, simulate) ->
    assert actionString? and typeof actionString is "string" 
    assert simulate? and typeof simulate is "boolean"

    for aH in @actionHandlers
      promise = aH.executeAction actionString, simulate
      if promise?.then?
        return promise
    return Q.fcall -> throw new Error("No actionhandler found!")

module.exports.RuleManager = RuleManager