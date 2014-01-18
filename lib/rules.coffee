# #rules handling

assert = require 'cassert'
logger = require "./logger"
util = require 'util'
Q = require 'q'
milliseconds = require './milliseconds'

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
  #         provider: the corresponding provider },
  #       { id: 'some-id1'
  #         provider: the corresponding provider }
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
  #     error: 'Could not find a provider that decides bla'
  #     active: false 
  #  
  rules: []
  # Array of ActionHandlers: see [actions.coffee](actions.html)
  actionHandlers: []
  # Array of predicateProviders: see [actions.coffee](actions.html)
  predicateProviders: []

  constructor: (@framework) ->

  addActionHandler: (ah) -> @actionHandlers.push ah
  addPredicateProvider: (pv) -> @predicateProviders.push pv

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
  #         provider: the corresponding provider },
  #       { id: 'some-id1'
  #         provider: the corresponding provider }
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

    rule = 
      id: id
      string: ruleString

    # Allways return a promise
    return Q.fcall( =>
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
      rule.orgCondition = parts[1].trim()
      # and `actions` gets `" turn the light off"`.
      rule.action = parts[2].trim()

      # Utility function, that finds a provider, that can decide the given predicate like `its 10pm`
      findPredicateProvider = (predicate) =>
        assert predicate? and typeof predicate is "string" and predicate.length isnt 0
        for provider in @predicateProviders
          type = provider.canDecide predicate
          assert type is 'event' or type is 'state' or type is no
          if type is 'event' or type is 'state'
            return [type, provider]
        return [null, null]

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
      for token in rule.orgCondition.split /(\sand\s|\sor\s|\)|\()/ 
        do (token) =>
          token = token.trim()
          if token in ["and", "or", ")", "("]
            tokens.push token
          else
            i = predicates.length
            predId = id+i

            forSuffix = null
            forTime = null

            # Try to split the predicate at the last `for` to handle 
            # predicates in the form `"the light is on for 10 seconds"`
            forMatches = token.match /(.+)\sfor\s(.+)/
            if forMatches? and forMatches?.length is 3
              beforeFor = forMatches[1].trim()
              afterFor = forMatches[2].trim()

              # Test if we can parse the afterFor part.
              ms = milliseconds.parse afterFor
              if ms?
                token = beforeFor
                forSuffix = afterFor
                forTime = ms

            [type, provider] = findPredicateProvider token
            if type is 'event' and forSuffix?
              throw new Error "\"#{token}\" is an event it can not be true for \"#{forSuffix}\""

            predicate =
              id: predId
              token: token
              type: type
              provider: provider
              forToken: forSuffix
              for: forTime

            if not predicate.provider?
              throw new Error "Could not find an provider that decides \"#{predicate.token}\""

            predicates.push(predicate)
            tokens = tokens.concat ["predicate", "(", i, ")"]
              
      rule.tokens = tokens
      rule.predicates = predicates

      # Simulate the action execution to try if it can be executed-
      return @executeAction(rule.action, true).then( =>
        # If the execution was sussessful then return the rule object.
        return rule 
      ).catch( (error) =>
        # If there was a Errror simulation the action exeution, return an error.
        logger.debug error
        throw new Error "Could not find a actuator to execute \"#{rule.action}\""
      )
    ).catch( (error) =>
      logger.info "rethrowing error: #{error.message}"
      logger.debug error.stack
      error.rule = rule
      throw error
    )

  # ###_whenPredicateIsTrue
  # Register for every predicate the callback function that should be called
  # when the predicate becomes true.
  _registerPredicateProviderNotify: (rule) ->
    assert rule?
    assert rule.predicates?

    # ###whenPredicateIsTrue
    # This function should be called by a provider if a predicate becomes true
    whenPredicateIsTrue = (ruleId, predicateId, state) =>
      assert ruleId? and typeof ruleId is "string" and ruleId.length isnt 0
      assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0
      assert state is 'event' or state is true

      # First get get the corresponding rule
      rule = @rules[ruleId]
      unless rule.active then return

      # Then mark the given predicate as true
      knownPredicates = {}
      knownPredicates[predicateId] = true

      # and check if the rule is now true.
      @doesRuleCondtionHold(rule, knownPredicates).then( (isTrue) =>
        # if the rule is now true, then execute its action
        if isTrue then @executeActionAndLogResult(rule).done()
        return
      ).done()
      return
    
    # Register the whenPredicateIsTrue for all providers:
    for p in rule.predicates
      do (p) =>
        p.provider.notifyWhen p.id, p.token, (state) =>
          assert state is 'event' or state is true or state is false
          if state is true or state is 'event'
            whenPredicateIsTrue rule.id, p.id, state
          
  # ###_cancelPredicateproviderNotify
  # Cancels for every predicate the callback that should be called
  # when the predicate becomes true.
  _cancelPredicateProviderNotify: (rule) ->
    assert rule?

    # Then cancel the notifier for all predicates
    if rule.valid
      p.provider.cancelNotify p.id for p in rule.predicates

  # ###AddRuleByString
  addRuleByString: (id, ruleString, active=yes, force=false) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    # First parse the rule.
    return @parseRuleString(id, ruleString).then( (rule)=>
      @_registerPredicateProviderNotify rule
      # If the rules was successful parsed add it to the rule array.
      rule.active = active
      rule.valid = yes
      @rules[id] = rule
      @emit "add", rule
      # Check if the condition of the rule is allready true.
      if active
        @doesRuleCondtionHold(rule).then( (isTrue) =>
          # If the confition is true then execute the action.
          if isTrue 
            @executeActionAndLogResult(rule).done()
          return
        ).done()
      return
    ).catch( (error) =>
      # If there was an error pasring the rule, but the rule is forced to be added, then add
      # the rule with an error
      if force
        if error.rule?
          rule = error.rule
          rule.error = error.message
          rule.active = false
          rule.valid = no
          @rules[id] = rule
          @emit 'add', rule
        else
          logger.error 'Could not force add rule, because error had no rule attribute.'
          logger.debug error
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
    @_cancelPredicateProviderNotify rule
    # and delete the rule from the array
    delete @rules[id]
    # and emit the event.
    @emit "remove", rule
    return

  # ###updateRuleByString
  updateRuleByString: (id, ruleString, active=yes) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"
    throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?

    # First try to parse the updated ruleString.
    return @parseRuleString(id, ruleString).then( (rule)=>
      rule.active = active
      rule.valid = yes
      # If the rule was successfully parsed then get the old rule
      oldRule = @rules[id]
      # and cancel the notifier for the old predicates.
      @_cancelPredicateProviderNotify rule
      # and register the new ones:
      @_registerPredicateProviderNotify rule

      # Then add the rule to the rules array
      @rules[id] = rule
      # and emit the event.
      @emit "update", rule
      # Then check if the condition of the rule is now true.
      if active
        @doesRuleCondtionHold(rule).then( (isTrue) =>
          # If the condition is true then exectue the action.
          return if isTrue then @executeActionAndLogResult(rule).done()
        ).done()
      return
    )

  # ###evaluateConditionOfRule
  # Uses 'bet' to evaluate rule.tokens
  evaluateConditionOfRule: (rule, knownPredicates = {}) ->
    assert rule? and rule instanceof Object
    assert knownPredicates? and knownPredicates instanceof Object

    awaiting = []
    predNumToId = []
    for pred, i in rule.predicates
      do (pred) =>
        predNumToId[i] = pred.id
        unless knownPredicates[pred.id]?
          awaiting.push pred.provider.isTrue(pred.id, pred.token).then (state) =>
            unless state?
              state = false
              logger.info "Could not decide #{pred.token} yet."
            knownPredicates[pred.id] = state

    return Q.all(awaiting).then( (predicateValues) =>
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
      exec: (args) => 
        predId = predNumToId[args[0]]
        assert knownPredicates[predId]?
        if knownPredicates[predId] then 1 else 0

      isTrue = (bet.evaluateSync(rule.tokens) is 1)
      return isTrue
    )


  doesRuleCondtionHold: (rule, knownPredicates = {}) ->
    assert rule? and rule instanceof Object   
    assert knownPredicates? and knownPredicates instanceof Object

    # First evaluate the condition and
    return @evaluateConditionOfRule(rule, knownPredicates).then( (isTrue) =>
      # if the condition is false then the condition con not hold, because it is already false
      # so return false.
      unless isTrue then return false
      # Some predicates could have a 'for'-Suffix like 'for 10 seconds' then the predicates 
      # must at least hold for 10 seconds to be true, so we have to wait 10 seconds to decide
      # if the rule is realy true

      # Create a deferred that will be resolve with the return value when the decision can be made. 
      deferred = Q.defer()

      # We will collect all predicates that have a for suffix and are not yet decideable in an 
      # awaiting list.
      awaiting = {}

      # Whenever an awaiting predicate gets resolved then we will revalidate the rule condition.
      revalidateCondition = () =>
        @evaluateConditionOfRule(rule, knownPredicates).then (isTrueNew) =>
          # If it is true
          if isTrueNew 
            # then resolve the return value as true
            deferred.resolve true
            # and cancel all awaitings.
            for id, a of awaiting
              a.cancel()
            return

          # Else check if we have awaiting predicates.
          # If we have no awaiting predicates
          if (id for id of awaiting).length is 0
            # then we can resolve the return value as false
            deferred.resolve false 
        .done()

      # Fill the awaiting list:
      # Check for each predicate,
      for pred in rule.predicates
        do (pred) => 
          # if it has a for suffix.
          if pred.for?
            # If it has a for suffix and its an event something gone wrong, because an event can't 
            # hold (its just one time)
            assert pred.type is 'state'
            # Create a new predicate id so we can register another listener.
            idNew = pred.id + "-for-" + (new Date().getTime())
            # Mark that we are awaiting the result
            awaiting[pred.id] = {}
            # and as long as we are awaiting the result, the predicate is false.
            knownPredicates[pred.id] = false

            # When the time passes
            timeout = setTimeout =>
              knownPredicates[pred.id] = true
              # the predicate remains true and no value is awaited anymore.
              awaiting[pred.id].cancel()
              revalidateCondition()
            , pred.for

            # Let us be notified when it becomes false.
            pred.provider.notifyWhen idNew, pred.token, (state) =>
              assert state is true or state is false
              # If it changes to false
              if state is false
                # then the predicate is false
                knownPredicates[pred.id] = false
                # and clear the timeout.
                awaiting[pred.id].cancel()
                revalidateCondition()

            awaiting[pred.id].cancel = =>
              delete awaiting[pred.id]
              clearTimeout timeout
              # and we can cancel the notify
              pred.provider.cancelNotify idNew

      # If we have not found awaiting predicates
      if (id for id of awaiting).length is 0
        # then resolve the return value to true.
        deferred.resolve true 
      # At then end return the deferred promise. 
      return deferred.promise
    )
    
  executeActionAndLogResult: (rule) ->
    return @executeAction(rule.action, false).then( (message) =>
      if message? then logger.info "Rule #{rule.id}: #{message}"
    ).catch( (error)=>
      logger.error "Rule #{rule.id} error: #{error}"
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