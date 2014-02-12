###
Rule System
===========

This file handles the parsing and executing of rules. 

What's a rule
------------
A rule is a string that has the format: "if _this_ then _that_". The _this_ part will be called 
the condition of the rule and the _that_ the actions of the rule.

__Examples:__

  * if its 10pm then turn the tv off
  * if its friday and its 8am then turn the light on
  * if (music is playing or the light is on) and somebody is present then turn the speaker on
  * if temperatue of living room is below 15°C for 5 minutes then log "its getting cold" 

__The condition and predicates__

The condition of a rule consists of one or more predicates. The predicates can be combined with
"and", "or" and can be grouped by parentheses. A predicate is either true or false at a given time. 
There are special predicates, called event-predicates, that represent events. These predicate are 
just true in the moment a special event happen.

Each predicate is handled by an Predicate Provider. Take a look at the 
[predicates file](predicates.html) for more details.

__for-suffix__

A predicate can have a "for" as a suffix like in "music is playing for 5 seconds" or 
"tv is on for 2 hours". If the predicate has a for-suffix then the rule action is only triggered,
when the predicate stays true the given time. Predicates that represent one time events like "10pm"
can't have a for-suffix because the condition can never hold.

__The actions__

The actions of a rule can consists of one or more actions. Each action describes a command that 
should be executed when the confition of the rule is true. Take a look at the 
[actions.coffee](actions.html) for more details.
###

 
assert = require 'cassert'
logger = require "./logger"
util = require 'util'
Q = require 'q'
_ = require 'lodash'
require "date-format-lite"

milliseconds = require './milliseconds'

###
The Rule Manager
----------------
The Rule Manager holds a collection of rules. Rules can be added to this collection. When a rule
is added the rule is parsed by the Rule Manager and for each predicate a Predicate Provider will
be searched. Predicate Provider that should be considered can be added to the Rule Manager.

If all predicates of the added rule can be handled by an Predicate Provider for each action of
the actions of the rule a Action Handler is searched. Action Handler can be added to the
Rule Manager, too.

###
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
  rules: {}
  # Array of ActionHandlers: see [actions.coffee](actions.html)
  actionHandlers: []
  # Array of predicateProviders: see [actions.coffee](actions.html)
  predicateProviders: []

  constructor: (@framework) ->

  addActionHandler: (ah) -> @actionHandlers.push ah
  addPredicateProvider: (pv) -> @predicateProviders.push pv

  # ###parseRuleString()
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
  parseRuleString: (id, ruleString, context) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    rule = 
      id: id
      string: ruleString

    # Allways return a promise
    return Q.fcall( =>
      
      ###
      First take the string apart, so that
       
          parts = ["", "its 10pm and light is on", "turn the light off"].
      
      ###
      parts = ruleString.split /^if\s|\sthen\s/
      # Check for the right parts count. Note the empty string at the beginning.
      switch
        when parts.length < 3
          throw new Error('The rule must start with "if" and contain a "then" part!')
        when parts.length > 3 
          throw new Error('The rule must exactly contain one "if" and one "then"!')
      ###
      Then extraxt the condition and actions from the rule 
       
          rule.orgCondition = "its 10pm and light is on"
          rule.actions = "turn the light off"
       
      ###
      rule.orgCondition = parts[1].trim()
      rule.action = parts[2].trim()

      result = @parseRuleCondition(id, rule.orgCondition, context)
      rule.predicates = result.predicates
      rule.tokens = result.tokens

      if context.hasErrors()
        return rule

      # Simulate the action execution to try if it can be executed-
      return @executeAction(rule.action, true, context).then( =>
        # If the execution was sussessful then return the rule object.
        return rule 
      ).catch( (error) =>
        # If there was a Errror simulation the action exeution, return an error.
        logger.error error.message
        logger.debug error.stack
        throw error
      )
    ).catch( (error) =>
      logger.debug "rethrowing error: #{error.message}"
      logger.debug error.stack
      error.rule = rule
      throw error
    )

  parseRuleCondition: (id, conditionString, context) ->
    assert typeof id is "string" and id.length isnt 0
    assert typeof conditionString is "string"
    assert context?
    ###
    Split the condition in a token stream.
    For example: 
      
        "12:30 and temperature > 10"
     
    becomes 
     
        ['12:30', 'and', 'temperature > 30 C']
     
    Then we replace all predicates with tokens of the following form
     
        tokens = ['predicate', '(', 0, ')', 'and', 'predicate', '(', 1, ')']
     
    and remember the predicates:
     
        predicates = [ {token: '12:30'}, {token: 'temperature > 10'}]
     
    We do this because we want o parse the condition with [bet](https://github.com/paulmoore/BET) 
    later and bet can only parse mathematical functions.
    ### 
    predicates = []
    tokens = []
    # For each token
    #(\sand\s|\sor\s)(?=(?:[^"]*"[^"]*")*[^"]*$)
    for token in conditionString.split /// 
      (             # split at
         \sand\s    # " and "
       | \sor\s     # " or "
       | \)         # ")"
       | \(         # "("
      ) 
      (?=           # fowolled by
        (?:
          [^"]*     # a string not containing an quote
          "[^"]*"   # a string in quotes
        )*          # multiples times
        [^"]*       # a string not containing quotes
      $) /// 
      do (token) =>
        tokenTrimed = token.trim()
        # if its no predicate then push it into the token stream
        if tokenTrimed in ["and", "or", ")", "("]
          tokens.push tokenTrimed
        else
          # else generate a unique id.
          i = predicates.length
          predId = id+i
          predicate = @parsePredicate(predId, token, context)
          predicates.push(predicate)
          tokens = tokens.concat ["predicate", "(", i, ")"]
    return {
      predicates: predicates
      tokens: tokens
    }

  parsePredicate: (predId, predicateString, context) =>
    assert typeof predId is "string" and predId.length isnt 0
    assert typeof predicateString is "string"
    assert context?

    forSuffix = null
    forTime = null

    # Try to split the predicate at the last `for` to handle 
    # predicates in the form `"the light is on for 10 seconds"`
    forMatches = predicateString.match /(.+)\sfor\s(.+)/
    if forMatches? and forMatches?.length is 3
      beforeFor = forMatches[1].trim()
      afterFor = forMatches[2].trim()

      # Test if we can parse the afterFor part.
      ms = milliseconds.parse afterFor
      if ms?
        predicateString = beforeFor
        forSuffix = afterFor
        forTime = ms


    # find a prdicate provider for that can parse and decide the predicate:
    suitedPredProvider = _(@predicateProviders).map( (provider) => 
      type = provider.canDecide predicateString, context
      assert type is 'event' or type is 'state' or type is no
      [provider, type]
    ).filter( ([provider, type]) => type isnt no ).value()

    provider = null
    type = null
    switch suitedPredProvider.length
      when 0
        context.addError("""Could not find an provider that decides "#{predicateString}".""")
      when 1
        [provider, type] = suitedPredProvider[0]
        if type is 'event' and forSuffix?
          context.addError("\"#{token}\" is an event it can not be true for \"#{forSuffix}\"")
      else
        context.addError("""Predicate "#{predicateString}" is ambiguous.""")

    predicate =
      id: predId
      token: predicateString
      type: type
      provider: provider
      forToken: forSuffix
      for: forTime

  # ###_registerPredicateProviderNotify()
  # Register for every predicate the callback function that should be called
  # when the predicate becomes true.
  _registerPredicateProviderNotify: (rule) ->
    assert rule?
    assert rule.predicates?
    
    # For all predicate providers
    for p in rule.predicates
      do (p) =>
        # let us be notified when the predicate state changes.
        p.provider.notifyWhen p.id, p.token, (state) =>
          assert state is 'event' or state is true or state is false
          #If the state is true then call the `whenPredicateIsTrue` function.
          if state is true or state is 'event'
            whenPredicateIsTrue rule.id, p.id, state

    # This function should be called by a provider if a predicate becomes true.
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
          
  # ###_cancelPredicateproviderNotify()
  # Cancels for every predicate the callback that should be called
  # when the predicate becomes true.
  _cancelPredicateProviderNotify: (rule) ->
    assert rule?

    # Then cancel the notifier for all predicates
    if rule.valid
      p.provider.cancelNotify p.id for p in rule.predicates

  # ###addRuleByString()
  addRuleByString: (id, ruleString, active=yes, force=false) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"

    context = @createParseContext()
    # First parse the rule.
    return @parseRuleString(id, ruleString, context).then( (rule)=>
      # If we have parse error we don't need to continue here
      if context.hasErrors()
        error = new Error context.getErrorsAsString()
        error.rule = rule
        error.context = context
        throw error

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
      return context
    ).catch( (error) =>
      # If there was an error pasring the rule, but the rule is forced to be added, then add
      # the rule with an error.
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

  # ###removeRule()
  # Removes a rule, from the Rule Manager.
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

  # ###updateRuleByString()
  updateRuleByString: (id, ruleString, active=yes) ->
    assert id? and typeof id is "string" and id.length isnt 0
    assert ruleString? and typeof ruleString is "string"
    throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?

    context = @createParseContext()
    # First try to parse the updated ruleString.
    return @parseRuleString(id, ruleString, context).then( (rule)=>
      if context.hasErrors()
        error = new Error context.getErrorsAsString()
        error.rule = rule
        error.context = context
        throw error

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

  # ###evaluateConditionOfRule()
  # Uses the 'bet' node.js module to evaluate rule.tokens. This function returnes a promise that
  # will be fulfilled with true if the condition of the rule is true. This function ignores all 
  # the "for"-suffixes of predicates. The `knownPredicates` is an object containing a value for
  # each predicate for that the state is already known.
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

  # ###doesRuleCondtionHold()
  # The same as evaluateConditionOfRule but does not ignore the for-suffixes.
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

  # ###executeActionAndLogResult()
  # Executes the actions of the string using `executeAction` and logs the result to the logger.    
  executeActionAndLogResult: (rule) ->
    currentTime = (new Date).getTime()
    if rule.lastExecuteTime?
      delta = currentTime - rule.lastExecuteTime
      if delta <= 2
        logger.debug "Suppressing rule #{rule.id} execute because it was executed resently."
        return Q()
    rule.lastExecuteTime = currentTime

    # Returns the current time as string: `2012-11-04 14:55:45`
    now = => new Date().format 'YYYY-MM-DD hh:mm:ss'
    context = @createParseContext()
    return @executeAction(rule.action, false, context).then( (messages) =>
      if context.hasErrors()
        throw new Error(context.errors[0])
      assert Array.isArray messages
      # concat the messages: `["a", "b"] => "a and b"`
      message = _.reduce(messages, (ms, m) => if m? then "#{ms} and #{m}" else ms)
      logger.info "#{now()}: rule #{rule.id}: #{message}"
    ).catch( (error)=>
      logger.error "#{now()}: rule #{rule.id} error: #{error}"
    )

  # ###executeAction()
  # Executes the actions in the given actionString
  executeAction: (actionString, simulate, context) ->
    assert actionString? and typeof actionString is "string" 
    assert simulate? and typeof simulate is "boolean"

    unless context? then context = @createParseContext()

    # Split the actionString at " and " and search for an Action Handler in each part.
    actionResults = []
    for token in actionString.split /// 
      \s+and\s+     # " and " 
      (?=           # fowolled by
        (?:
          [^"]*     # a string not containing an quote
          "[^"]*"   # a string in quotes
        )*          # multiples times
        [^"]*       # a string not containing quotes
      $) /// 
      ahFound = false
      for aH in @actionHandlers
        unless ahFound
          try 
            # Check if the action handler can execute the action. If it can execute it then
            # it should do it and return a promise that get fulfilled with a description string.
            # If the action handler can't handle the action it should return null.
            promise = aH.executeAction token, simulate, context
            # If the action was handled
            if Q.isPromise promise
              # push it to the results and continue with the next token.
              actionResults.push promise
              ahFound = true
              continue
          catch e 
            errorMsg = "Error executing a action handler: #{e.message}"
            context.addError(errorMsg)
            logger.error errorMsg
            logger.debug e.stack
      unless ahFound
        context.addError("Could not find an action handler for: #{token}")

    if not simulate and context.hasErrors()
      return Q.fcall => 
        error = new Error("Could not execute an action: #{context.getErrorsAsString()}")
        error.context = context
        throw error

    return Q.all(actionResults)

  createParseContext: ->
    return context = {
      autocomplete: []
      errors: []
      warnings: []
      addHint: ({autocomplete: a}) ->
        if Array.isArray a 
          @autocomplete = @autocomplete.concat a
        else @autocomplete.push a
      addError: (message) -> @errors.push message
      addWarning: (message) -> @warnings.push message
      hasErrors: -> (@errors.length > 0)
      getErrorsAsString: -> _(@errors).reduce((ms, m) => "#{ms}, #{m}")
      finalize: () -> 
        @autocomplete = _(@autocomplete).uniq().sortBy((s)=>s.toLowerCase()).value()
    }

module.exports.RuleManager = RuleManager