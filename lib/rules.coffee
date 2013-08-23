should = require 'should'

class RuleManager
  rules: []
  server: null
  actionHandlers: []

  constructor: (@server) ->

  findSensorForPredicate: (id, predicate, callback) ->
    should.exist id
    should.exist predicate
    should.exist callback
    id.should.be.a("string").not.empty
    predicate.should.be.a("string").not.empty

    for sensorId, sensor of @server.sensors
      if sensor.notifyWhen id, predicate, callback
        return sensor
    return null

  predicateIsTrue: (ruleId, predicateId) ->
    should.exist ruleId
    should.exist predicateID
    ruleId.should.be.a("string").not.empty()
    predicateId.should.be.a("string").not.empty()

    knownTruePredicates = []
    knownTruePredicates.push predicateId
    rule = @rules[ruleId]
    trueOrFalse = @evaluateConditionOfRule rule, knownTruePredicates
    if trueOrFalse then executeAction rule.actions, false, (e, message)->
      console.log "Rule #{ruleId} error: #{e}" if e?
      console.log "Rule #{ruleId}: #{message}" if message?

  addRuleByString: (id, ruleString) ->
    _this = this
    #First take the string apart:
    parts = ruleString.split /^if\s|\sthen\s/
    #parts should now be ["", "the if part", "the then part"]
    console.log parts
    switch
      when parts.length < 3 then throw new Error('The rule must start with "if" and contain a "then" part!')
      when parts.length > 3 then throw new Error('The rule must exactly contain one "if" and one "then"!')
    condition = parts[1].trim();
    actions = parts[2].trim();

    console.log "condition: #{condition}, actions #{actions}"

    #Split the condition in a token stream.
    #For example: "12:30 and temperature > 10" becoms
    #['12:30', 'and', 'temperature > 30 C']
    #Then we replace all predicates throw predicate tokens:
    #['predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')']
    #and remember the predicates in predicates
    #predicates = [ {token: '12:30'}, {token: 'temperature > 10'}]
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
    
    #Ok now the easier part: the action
    ok = _this.executeAction actions, true, -> 
    if not ok then throw Error "Could not find a actuator to execute \"#{actions}\""

    #Now we cann add the rule to ower rules array
    @rules[id] =
      orgCondition: condition
      predicates: predicates
      tokens: tokens
      action: actions

    #Check if the condition of the rule is allready true
    trueOrFalse = @evaluateConditionOfRule @rules[id]
    console.log "Rule condition was #{trueOrFalse}"

  #Uses 'bet' to evaluate rule.tokens
  evaluateConditionOfRule: (rule, knownTruePredicates = []) ->
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
    for aH in @actionHandlers
      actionFunc = aH.executeAction actionString, simulate, callback
      if actionFunc?
        actionFunc()
        return true
      else
        return false

module.exports.RuleManager = RuleManager