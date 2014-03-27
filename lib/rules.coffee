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
util = require 'util'
Q = require 'q'
_ = require 'lodash'
S = require 'string'
M = require './matcher'
require "date-format-lite"

milliseconds = require './milliseconds'

module.exports = (env) ->

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
    #     conditionToken: 'its 10pm and light is on'
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
    actionProviders: []
    # Array of predicateProviders: see [actions.coffee](actions.html)
    predicateProviders: []

    constructor: (@framework) ->

    addActionProvider: (ah) -> @actionProviders.push ah
    addPredicateProvider: (pv) -> @predicateProviders.push pv

    # ###parseRuleString()
    # This function parses a rule given by a string and returns a rule object.
    # A rule string is for example 'if its 10pm and light is on then turn the light off'
    # it get parsed to the follwoing rule object:
    #  
    #     id: 'some-id'
    #     string: 'if its 10pm and light is on then turn the light off'
    #     conditionToken: 'its 10pm and light is on'
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
         
            rule.conditionToken = "its 10pm and light is on"
            rule.actions = "turn the light off"
         
        ###
        rule.conditionToken = parts[1].trim()
        rule.actionsToken = parts[2].trim()

        if rule.conditionToken.length is 0
          throw new Error("Condition part of rule #{id} is empty.")
        if rule.actionsToken.length is 0
          throw new Error("Actions part of rule #{id} is empty.")

        result = @parseRuleCondition(id, rule.conditionToken, context)
        rule.predicates = result.predicates
        rule.tokens = result.tokens

        unless context.hasErrors()
          result = @parseRuleActions(id, rule.actionsToken, context)
          rule.actions = result.actions
          rule.actionTokens = result.tokens

        return rule
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

      nextInput = conditionString

      success = yes
      openedParentheseCount = 0

      while (not context.hasErrors()) and nextInput.length isnt 0
        openedParentheseMatch = yes
        while openedParentheseMatch
          m = M(nextInput, context).match('(', => 
            tokens.push '('
            openedParentheseCount++
            nextInput = nextInput.substring(1)
          )
          openedParentheseMatch = not m.hadNoMatches()

        i = predicates.length
        predId = "prd-#{id}-#{i}"

        { predicate, token, nextInput } = @parsePredicate(predId, nextInput, context)
        unless context.hasErrors()
          predicates.push(predicate)
          tokens = tokens.concat ["predicate", "(", i, ")"]

          closeParentheseMatch = yes
          while closeParentheseMatch and openedParentheseCount > 0
            m = M(nextInput, context).match(')', => 
              tokens.push ')'
              closeParentheseMatch--
              nextInput = nextInput.substring(1)
            )
            closeParentheseMatch = not m.hadNoMatches()

          # Try to match " and ", " or ", ...
          possibleTokens = [' and ', ' or ']
          onMatch = (m, s) => tokens.push s.trim()
          m = M(nextInput, context).match(possibleTokens, onMatch)
          unless nextInput.length is 0
            if m.hadNoMatches()
              context.addError("""Expected one of: "and", "or", ")".""")
            else
              token = m.getLongestFullMatch()
              assert S(nextInput.toLowerCase()).startsWith(token.toLowerCase())
              nextInput = nextInput.substring(token.length)
      return {
        predicates: predicates
        tokens: tokens
      }

    parsePredicate: (predId, nextInput, context) =>
      assert typeof predId is "string" and predId.length isnt 0
      assert typeof nextInput is "string"
      assert context?


      predicate =
        id: predId
        token: null
        handler: null
        forToken: null
        for: null

      # find a prdicate provider for that can parse and decide the predicate:
      parseResults = []
      for predProvider in @predicateProviders
        parseResult = predProvider.parsePredicate(nextInput, context)
        if parseResult?
          assert parseResult.token? and parseResult.token.length > 0
          assert parseResult.nextInput? and typeof parseResult.nextInput is "string"
          assert parseResult.predicateHandler?
          assert parseResult.predicateHandler instanceof env.predicates.PredicateHandler
          parseResults.push parseResult

      token = null

      switch parseResults.length
        when 0
          context.addError(
            """Could not find an provider that decides next predicate of "#{nextInput}"."""
          )
        when 1
          # get part of nextInput that is related to the found provider
          parseResult = parseResults[0]
          token = parseResult.token
          assert token?
          assert S(nextInput.toLowerCase()).startsWith(token.toLowerCase())
          predicate.token = token
          nextInput = parseResult.nextInput
          predicate.handler = parseResult.predicateHandler

          timeParseResult = @parseTimePart(nextInput, " for ", context)

          if timeParseResult?
            token += timeParseResult.token
            nextInput = timeParseResult.nextInput
            predicate.forToken = timeParseResult.timeToken
            predicate.for = timeParseResult.time

          if predicate.handler.getType() is 'event' and predicate.forToken?
            context.addError(
              "\"#{token}\" is an event it can not be true for \"#{redicate.forToken}\"."
            )

        else
          context.addError(
            """Next predicate of "#{nextInput}" is ambiguous."""
          )

      return { predicate, token, nextInput }

    parseTimePart: (nextInput, prefixToken, context, options = null) ->
      # Parse the for-Suffix:
      timeUnits = [
        "ms", 
        "second", "seconds", "s", 
        "minute", "minutes", "m", 
        "hour", "hours", "h", 
        "day", "days","d", 
        "year", "years", "y"
      ]
      time = 0
      unit = ""
      onTimeMatch = (m, n) => time = parseFloat(n)
      onMatchUnit = (m, u) => unit = u

      m = M(nextInput, context)
        .match(prefixToken, options)
        .matchNumber(onTimeMatch)
        .match(
          _(timeUnits).map((u) => [" #{u}", u]).flatten().valueOf()
        , {acFilter: (u) => u[0] is ' '}, onMatchUnit
        )

      unless m.hadNoMatches()
        token = m.getLongestFullMatch()
        assert S(nextInput).startsWith(token)
        timeToken = S(token).chompLeft(prefixToken).s
        time = milliseconds.parse "#{time} #{unit}"
        nextInput = nextInput.substring(token.length)
        return {token, nextInput, timeToken, time}
      else
        return null

    parseRuleActions: (id, nextInput, context) ->
      assert typeof id is "string" and id.length isnt 0
      assert typeof nextInput is "string"
      assert context?

      actions = []
      tokens = []
      # For each token

      success = yes
      openedParentheseCount = 0

      while (not context.hasErrors()) and nextInput.length isnt 0
        i = actions.length
        actionId = "act-#{id}-#{i}"
        { action, token, nextInput } = @parseAction(actionId, nextInput, context)
        unless context.hasErrors()
          actions.push action
          tokens = tokens.concat ['action', '(', i, ')']
          # actions.push {
          #   token: token
          #   handler: 
          # }
          onMatch = (m, s) => tokens.push s.trim()
          m = M(nextInput, context).match([' and '], onMatch)
          unless nextInput.length is 0
            if m.hadNoMatches()
              context.addError("""Expected: "and".""")
            else
              token = m.getLongestFullMatch()
              assert S(nextInput.toLowerCase()).startsWith(token.toLowerCase())
              nextInput = nextInput.substring(token.length)
      return {
        actions: actions
        tokens: tokens
      }

    parseAction: (actionId, nextInput, context) =>
      assert typeof nextInput is "string"
      assert context?

      token = null

      action =
        id: actionId
        token: null
        handler: null
        afterToken: null
        after: null
        forToken: null
        for: null

      parseAfter = (type) =>
        prefixToken =  (if type is "prefix" then "after " else " after ")
        timeParseResult = @parseTimePart(nextInput, prefixToken, context)
        if timeParseResult?
          nextInput = timeParseResult.nextInput
          if type is 'prefix'
            if nextInput.length > 0 and nextInput[0] is ' '
              nextInput = nextInput.substring(1)
          action.afterToken = timeParseResult.timeToken
          action.after = timeParseResult.time
        
      # Try to macth after as prefix: after 10 seconds log "42" 
      parseAfter('prefix')

      token = null

      # find a prdicate provider for that can parse and decide the predicate:
      parseResults = []
      for actProvider in @actionProviders
        parseResult = actProvider.parseAction(nextInput, context)
        if parseResult?
          assert parseResult.token? and parseResult.token.length > 0
          assert parseResult.nextInput? and typeof parseResult.nextInput is "string"
          assert parseResult.actionHandler?
          assert parseResult.actionHandler instanceof env.actions.ActionHandler
          parseResults.push parseResult

      switch parseResults.length
        when 0
          context.addError(
            """Could not find an provider that provides the next action of "#{nextInput}"."""
          )
        when 1
          # get part of nextInput that is related to the found provider
          parseResult = parseResults[0]
          token = parseResult.token
          assert token?
          assert S(nextInput.toLowerCase()).startsWith(parseResult.token.toLowerCase())
          action.token = token
          nextInput = parseResult.nextInput
          action.handler = parseResult.actionHandler

          # try to match after as suffix: log "42" after 10 seconds
          unless action.afterToken?
            parseAfter('suffix')

          # try to parse "for 10 seconds"
          forSuffixAlloed = action.handler.hasRestoreAction()
          timeParseResult = @parseTimePart(nextInput, " for ", context, {
            acFilter: () => forSuffixAlloed
          })
          if timeParseResult?
            nextInput = timeParseResult.nextInput
            action.forToken = timeParseResult.timeToken
            action.for = timeParseResult.time

          if action.forToken? and forSuffixAlloed is no
            context.addError(
              """Action "#{action.token}" can't have an "for"-Suffix."""
            )
          
        else
          context.addError(
            """Next action of "#{nextInput}" is ambiguous."""
          )

      return { action, token, nextInput }

    # ###_addPredicateChangeListener()
    # Register for every predicate the callback function that should be called
    # when the predicate becomes true.
    _addPredicateChangeListener: (rule) ->
      assert rule?
      assert rule.predicates?
      
      # For all predicate providers
      for p in rule.predicates
        do (p) =>
          assert(not p.changeListener?)
          p.handler.setup()
          # let us be notified when the predicate state changes.
          p.handler.on 'change', changeListener = (state) =>
            assert state is 'event' or state is true or state is false
            #If the state is true then call the `whenPredicateIsTrue` function.
            if state is true or state is 'event'
              whenPredicateIsTrue rule, p.id, state
          p.changeListener = changeListener

      # This function should be called by a provider if a predicate becomes true.
      whenPredicateIsTrue = (rule, predicateId, state) =>
        assert rule?
        assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0
        assert state is 'event' or state is true

        # if not active, then nothing to do
        unless rule.active then return

        # Then mark the given predicate as true
        knownPredicates = {}
        knownPredicates[predicateId] = true

        # and check if the rule is now true.
        @doesRuleCondtionHold(rule, knownPredicates).then( (isTrue) =>
          # if the rule is now true, then execute its action
          if isTrue 
            return @executeRuleActionsAndLogResult(rule)
        ).catch( (error) => 
          env.logger.error """
            Error on evaluation of rule condition of rule #{rule.id}: #{error.message}
          """ 
          env.logger.debug error
        )
        return
            
    # ###_cancelPredicateproviderNotify()
    # Cancels for every predicate the callback that should be called
    # when the predicate becomes true.
    _removePredicateChangeListener: (rule) ->
      assert rule?
      # Then cancel the notifier for all predicates
      if rule.valid
        for p in rule.predicates
          do (p) =>
            assert typeof p.changeListener is "function"
            p.handler.removeListener 'change', p.changeListener
            delete p.changeListener
            p.handler.destroy()

    _cancelScheduledActions: (rule) ->
      assert rule?
      # Then cancel the notifier for all predicates
      if rule.valid
        for action in rule.actions
          if action.scheduled?
            action.scheduled.cancel(
              "canceling schedule of action #{action.token}"
            )

    # ###addRuleByString()
    addRuleByString: (id, ruleString, active=yes, force=false) ->
      assert id? and typeof id is "string" and id.length isnt 0
      assert ruleString? and typeof ruleString is "string"

      unless id.match /^[a-z0-9\-_]+$/i then throw new Error "rule id must only contain " +
        "alpha numerical symbols, \"-\" and  \"_\""
      if @rules[id]? then throw new Error "There is already a rule with the id \"#{id}\""

      context = @createParseContext()
      # First parse the rule.
      return @parseRuleString(id, ruleString, context).then( (rule)=>
        # If we have parse error we don't need to continue here
        if context.hasErrors()
          error = new Error context.getErrorsAsString()
          error.rule = rule
          error.context = context
          throw error

        @_addPredicateChangeListener rule
        # If the rules was successful parsed add it to the rule array.
        rule.active = active
        rule.valid = yes
        @rules[id] = rule
        @emit "add", rule
        # Check if the condition of the rule is allready true.
        return Q(
          if active
            @doesRuleCondtionHold(rule).then( (isTrue) =>
              # If the confition is true then execute the action.
              if isTrue 
                return @executeRuleActionsAndLogResult(rule)
            ).catch( (error) =>
              env.logger.error """
                Error on evaluation of rule condition of rule #{rule.id}: #{error.message}
              """ 
              env.logger.debug error
            )
        ).then( => context )
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
            env.logger.error 'Could not force add rule, because error had no rule attribute.'
            env.logger.debug error
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
      @_removePredicateChangeListener(rule)
      @_cancelScheduledActions(rule)
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
        @_removePredicateChangeListener(oldRule)
        @_cancelScheduledActions(oldRule)
        # and register the new ones:
        @_addPredicateChangeListener rule
        # Then add the rule to the rules array
        @rules[id] = rule
        # and emit the event.
        @emit "update", rule
        # Then check if the condition of the rule is now true.
        return Q(
          if active
            @doesRuleCondtionHold(rule).then( (isTrue) =>
              # If the condition is true then exectue the action.
              return if isTrue then @executeRuleActionsAndLogResult(rule)
            )
        )
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
            awaiting.push pred.handler.getValue().then( (state) =>
              unless state?
                state = false
                env.logger.info "Could not decide #{pred.token} yet."
              knownPredicates[pred.id] = state
            )

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

        # Create a deferred that will be resolve with the return value when the decision can be 
        # made. 
        deferred = Q.defer()

        # We will collect all predicates that have a for suffix and are not yet decideable in an 
        # awaiting list.
        awaiting = {}

        # Whenever an awaiting predicate gets resolved then we will revalidate the rule condition.
        reevaluateCondition = () =>
          return @evaluateConditionOfRule(rule, knownPredicates).then( (isTrueNew) =>
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
          ).catch( (error) => 
            env.logger.error """
              Error on evaluation of rule condition of rule #{rule.id}: #{error.message}
            """ 
            env.logger.debug error
            deferred.reject error.message
          )

        # Fill the awaiting list:
        # Check for each predicate,
        for pred in rule.predicates
          do (pred) => 
            # if it has a for suffix.
            if pred.for?
              # If it has a for suffix and its an event something gone wrong, because an event 
              # can't hold (its just one time)
              assert pred.handler.getType() is 'state'
              # Mark that we are awaiting the result
              awaiting[pred.id] = {}
              # and as long as we are awaiting the result, the predicate is false.
              knownPredicates[pred.id] = false

              # When the time passes
              timeout = setTimeout =>
                knownPredicates[pred.id] = true
                # the predicate remains true and no value is awaited anymore.
                awaiting[pred.id].cancel()
                reevaluateCondition()
              , pred.for

              # Let us be notified when it becomes false.
              pred.handler.on 'change', changeListener = (state) =>
                assert state is true or state is false
                # If it changes to false
                if state is false
                  # then the predicate is false
                  knownPredicates[pred.id] = false
                  # and clear the timeout.
                  awaiting[pred.id].cancel()
                  reevaluateCondition()

              awaiting[pred.id].cancel = =>
                delete awaiting[pred.id]
                clearTimeout timeout
                # and we can cancel the notify
                pred.handler.removeListener 'change', changeListener

        # If we have not found awaiting predicates
        if (id for id of awaiting).length is 0
          # then resolve the return value to true.
          deferred.resolve true 
        # At then end return the deferred promise. 
        return deferred.promise.catch( (error) =>
          # Cancel all awatting changeHandler
          for id, a of awaiting
            a.cancel()
          throw error
        )
      )

    # ###executeRuleActionsAndLogResult()
    # Executes the actions of the string using `executeAction` and logs the result to 
    # the env.logger.    
    executeRuleActionsAndLogResult: (rule) ->
      currentTime = (new Date).getTime()
      if rule.lastExecuteTime?
        delta = currentTime - rule.lastExecuteTime
        if delta <= 500
          env.logger.debug "Suppressing rule #{rule.id} execute because it was executed resently."
          return Q()
      rule.lastExecuteTime = currentTime

      actionResults = @executeRuleActions(rule, false)

      logMessageForResult = (actionResult) =>
        return actionResult.then( (result) =>
          [message, next] = (
            if typeof result is "string" then [result, null]
            else 
              assert Array.isArray result
              assert result.length is 2
              result
          )
          env.logger.info "rule #{rule.id}: #{message}"
          if next?
            assert Q.isPromise(next)
            next = logMessageForResult(next)
          return [message, next]
        ).catch( (error) =>
          env.logger.error "rule #{rule.id} error executing an action: #{error.message}"
          env.logger.debug error.stack
        )

      for actionResult in actionResults
        actionResult = logMessageForResult(actionResult)
      return Q.all(actionResults)

    # ###executeAction()
    # Executes the actions in the given actionString
    executeRuleActions: (rule, simulate) ->
      assert rule?
      assert rule.actions?
      assert simulate? and typeof simulate is "boolean"

      actionResults = []
      for action in rule.actions
        do (action) =>
          promise = null
          if action.after?
            unless simulate 
              # cancel scheule for pending executes
              if action.scheduled?
                action.scheduled.cancel(
                  "reschedule action #{action.token} in #{action.afterToken}"
                ) 
              # schedule new action
              promise = @scheduleAction(action, action.after)
            else
              promise = @executeAction(action, simulate).then( (message) => 
                "#{message} after #{action.afterToken}"
              )
          else
            promise = @executeAction(action)
          assert Q.isPromise(promise)
          actionResults.push promise
      return actionResults

    executeAction: (action, simulate) =>
      # wrap into an fcall to convert throwen erros to a rejected promise
      return Q.fcall( => 
        promise = action.handler.executeAction(simulate) 
        if action.for?
          promise = promise.then( (message) =>
            restoreActionPromise = @scheduleAction(action, action.for, yes)
            return [message, restoreActionPromise]
          )
        return promise
      )

    executeRestoreAction: (action, simulate) =>
      # wrap into an fcall to convert throwen erros to a rejected promise
      return Q.fcall( => action.handler.executeRestoreAction(simulate) )

    scheduleAction: (action, ms, isRestore = no) =>
      assert action?
      if action.scheduled?
        action.scheduled.cancel("clearing scheduled action")

      deferred = Q.defer()
      timeoutHandle = setTimeout((=> 
        promise = (
          unless isRestore then @executeAction(action, no)
          else @executeRestoreAction(action, no)
        )
        deferred.resolve(promise)
        delete action.scheduled
      ), ms)
      action.scheduled = {
        startDate: new Date()
        cancel: (reason) =>
          clearTimeout(timeoutHandle)
          delete action.scheduled
          deferred.resolve(reason)
      }
      return deferred.promise

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

  return exports = { RuleManager }