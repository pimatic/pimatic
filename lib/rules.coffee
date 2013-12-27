# #rules handling

assert = require 'cassert'
logger = require "./logger"
util = require 'util'
Q = require 'q'

# ##RuleManager
class RuleManager extends require('events').EventEmitter
  # Array of the added rules
  # If a rule was successfully added, the rule has the form:
  # 
  #     id: 'some-id'
  #     string: 'if its 10pm and light is on then turn the light off'
  #     orgCondition: 'its 10pm and light is on'
  #     predicates: [
  #       { id: 'some-id0'
  #         sensor: the corresponding sensor },
  #       { id: 'some-id1'
  #         sensor: the corresponding sensor }
  #     ]
  #     tokens: ['predicate', '(', 0, ')', 'and', 
  #              'predicate', '(', 1, ')' ] 
  #     action: 'turn the light off'
  #     active: false or true
  # 
  # If the rule had an error:
  # 
  #     id: id
  #     string: 'if bla then blub'
  #     error: 'Could not find a sensor that decides bla'
  #     active: false 
  # 
  rules: []
  # Array of ActionHandlers: see [actions.coffee](actions.html)
  actionHandlers: []

  constructor: (@framework) ->

  # ###whenPredicateIsTrue
  # This function should be called by a sensor if a predicate becomes true
  whenPredicateIsTrue: (ruleId, predicateId) =>
    assert ruleId? and typeof ruleId is "string" and ruleId.length isnt 0
    assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0

    # First mark the given predicate as true, so wie dont check the predicate again.
    knownTruePredicates = [predicateId]
    # Then get the corresponding rule
    rule = @rules[ruleId]

    # and check if the rule is now true.
    @evaluateConditionOfRule(rule, knownTruePredicates).then( (isTrue) =>
      # if the rule is now true, then execute its action
      if isTrue then @executeAction(rule.action, false).then( (message) =>
        logger.info "Rule #{ruleId}: #{message}"
      ).catch( (error)=>
        logger.error "Rule #{ruleId} error: #{error}"
      ).done()
    )
    return

  # ###parseRuleString
  # This function parses a rule given by a string and returns a rule object.
  # A rule string is for example 'if its 10pm and light is on then turn the light off'
  # it get parsed to the follwoing rule object:
  # 
  #     id: 'some-id'
  #     string: 'if its 10pm and light is on then turn the light off'
  #     orgCondition: 'its 10pm and light is on'
  #     predicates: [
  #       { id: 'some-id0'
  #         sensor: the corresponding sensor },
  #       { id: 'some-id1'
  #         sensor: the corresponding sensor }
  #     ]
  #     tokens: ['predicate', '(', 0, ')', 'and', 
  #              'predicate', '(', 1, ')' ] 
  #     action: 'turn the light off'
  #     active: false or true
  # 
  # The function returns a promise!
  parseRuleString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    # Allways return a promise
    return Q.fcall =>
      # First take the string apart, so that 
      # `parts` gets `["", "its 10pm and light is on", "turn the light off"]`.
      parts = ruleString.split /^if\s|\sthen\s/
      # Check for the right parts count. Note the empty string at the beginning
      switch
        when parts.length < 3
          throw new Error('The rule must start with "if" and contain a "then" part!')
        when parts.length > 3 
          throw new Error('The rule must exactly contain one "if" and one "then"!')
      # Now `condition` gets `"its 10pm and light is on"`
      condition = parts[1].trim()
      # and `actions` gets `" turn the light off"`.
      actions = parts[2].trim()

      # Utility function, that finds a sensor, that can decide the given predicate like `its 10pm`
      findSensorForPredicate = (predicate) =>
        assert predicate? and typeof predicate is "string" and predicate.length isnt 0
        for sensorId, sensor of @framework.sensors
          if sensor.canDecide predicate
            return sensor
        return null

      # Now split the condition in a token stream.
      # For example: `"12:30 and temperature > 10"` becomes 
      # `['12:30', 'and', 'temperature > 30 C']`
      # 
      # Then we replace all predicates throw predicate tokens:
      # `['predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')']`
      # 
      # and remember the predicates:
      # `predicates = [ {token: '12:30'}, {token: 'temperature > 10'}]`
      predicates = []
      tokens = []
      for token in condition.split /(\sand\s|\sor\s|\)|\()/ 
        do (token) =>
          token = token.trim()
          if token in ["and", "or", ")", "("]
            tokens.push token
          else
            i = predicates.length
            predId = id+i
            predSensor = findSensorForPredicate token

            predicate =
              id: predId
              token: token
              sensor: predSensor

            if not predicate.sensor?
              throw new Error "Could not find an sensor that decides \"#{predicate.token}\""

            predicates.push(predicate)
            tokens = tokens.concat ["predicate", "(", i, ")"]
              

      # Simulate the action execution to try if it can be executed-
      return @executeAction(actions, true).then( =>

        # If the execution was sussessful then return the rule object.
        return rule = 
          id: id
          orgCondition: condition
          predicates: predicates
          tokens: tokens
          action: actions
          string: ruleString
      ).catch( (error) =>
        # If there was a Errror simulation the action exeution, return an error.
        logger.debug error
        throw new Error "Could not find a actuator to execute \"#{actions}\""
      )

  _registerPredicateSensorNotify: (rule) ->
    assert rule?
    assert rule.predicates?
    
    # Register all sensors:
    for p in rule.predicates
      do (p) =>
        p.sensor.notifyWhen p.id, p.token, =>
          @whenPredicateIsTrue rule.id, p.id

  _cancelPredicateSensorNotify: (rule) ->
    assert rule?
    assert rule.predicates?

    # Then cancel the notifier for all predicates
    p.sensor.cancelNotify p.id for p in rule.predicates

  # ###AddRuleByString
  addRuleByString: (id, ruleString, active=yes, force=false) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    # First parse the rule.
    return @parseRuleString(id, ruleString).then( (rule)=>

      @_registerPredicateSensorNotify rule
      # If the rules was successful parsed add it to the rule array.
      rule.active = active
      @rules[id] = rule
      @emit "add", rule
      # Check if the condition of the rule is allready true.
      if active
        @evaluateConditionOfRule(rule).then( (isTrue) ->
          # If the confition is true then execute the action.
          if isTrue then @executeAction(rule.action, false).then( (message) =>
            logger.info "Rule #{ruleId}: #{message}"
          ).catch( (error)=>
            logger.error "Rule #{ruleId} error: #{error}"
          )
        )
      return
    ).catch( (error) =>
      # If there was an error pasring the rule, but the rule is forced to be added, then add
      # the rule with an error.
      if force
        rule = 
          id: id
          string: ruleString
          error: error.message
          active: false
        @rules[id] = rule
        rule.emit 'add', rule
      throw error
    )

  # ###removeRule
  # Removes a rule, from the RuleManager
  removeRule: (id) ->
    assert id? and typeof id is "string" and id.length isnt 0
    throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?

    # First get the rule from the rule array.
    rule = @rules[id]
    # Then get cancel all notifies
    @_cancelPredicateSensorNotify rule
    # and delete the rule from the array
    delete @rules[id]
    # and emit the event.
    @emit "remove", rule
    return

  # ###updateRuleByString
  updateRuleByString: (id, ruleString) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"
    throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?

    # First try to parse the updated ruleString.
    return @parseRuleString(id, ruleString).then( (rule)=>
      # If the rule was successfully parsed then get the old rule
      oldRule = @rules[id]
      # and cancel the notifier for the old predicates.
      @_cancelPredicateSensorNotify rule
      # and register the new ones:
      @_registerPredicateSensorNotify rule

      # Then add the rule to the rules array
      @rules[id] = rule
      # and emit the event.
      @emit "update", rule
      # Then check if the condition of the rule is now true.
      return @evaluateConditionOfRule(rule).then( (isTrue) =>
        # If the condition is true then exectue the action.
        if isTrue then @executeAction(rule.action, false).then( (message) =>
          logger.info "Rule #{id}: #{message}"
        ).catch( (error)=>
          logger.error "Rule #{id} error: #{error}"
        )
      )
    )

  # ###evaluateConditionOfRule
  # Uses 'bet' to evaluate rule.tokens
  evaluateConditionOfRule: (rule, knownTruePredicates = []) ->
    assert rule? and rule instanceof Object
    assert Array.isArray knownTruePredicates

    predicateValues = []
    for pred in rule.predicates
      if pred.id in knownTruePredicates
        predicateValues.push (Q.fcall => true)
      else
        predicateValues.push (pred.sensor.isTrue pred.id, pred.token)

    return Q.all(predicateValues).then( (predicateValues) =>
      bet = require 'bet'
      bet.operators['and'] =
        assoc: 'left'
        prec: 0
        argc: 2
        fix: 'in'
        exec: (args) => if args[0] isnt 0 and args[1] isnt 0 then 1 else 0
      bet.operators['or'] =
        assoc: 'left'
        prec: 1
        argc: 2
        fix: 'in'
        exec: (args) => if args[0] isnt 0 or args[1] isnt 0 then 1 else 0
      bet.functions['predicate'] =
      argc: 1
      exec: (args) => if predicateValues[args[0]] then 1 else 0

      return bet.evaluateSync rule.tokens
    )

  # ###executeAction
  executeAction: (actionString, simulate) ->
    assert actionString? and typeof actionString is "string" 
    assert simulate? and typeof simulate is "boolean"

    for aH in @actionHandlers
      promise = aH.executeAction actionString, simulate
      if promise?.then?
        return promise
    return Q.fcall => throw new Error("No actionhandler found!")

module.exports.RuleManager = RuleManager