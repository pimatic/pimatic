###
Rule System
===========

This file handles the parsing and executing of rules. 

What's a rule
------------
A rule is a string that has the format: "when _this_ then _that_". The _this_ part will be called 
the condition of the rule and the _that_ the actions of the rule.

__Examples:__

  * when its 10pm then turn the tv off
  * when its friday and its 8am then turn the light on
  * when [music is playing or the light is on] and somebody is present then turn the speaker on
  * when temperature of living room is below 15°C for 5 minutes then log "its getting cold"

__The condition and predicates__

The condition of a rule consists of one or more predicates. The predicates can be combined with
"and", "or" and can be grouped by parentheses ('[' and ']'). A predicate is either true or false at 
a given time. There are special predicates, called event-predicates, that represent events. 
These predicate are just true in the moment a special event happen.

Each predicate is handled by a Predicate Provider. Take a look at the 
[predicates file](predicates.html) for more details.

__for-suffix__

A predicate can have a "for" as a suffix like in "music is playing for 5 seconds" or 
"tv is on for 2 hours". If the predicate has a for-suffix then the rule action is only triggered,
when the predicate stays true the given time. Predicates that represent one time events like "10pm"
can't have a for-suffix because the condition can never hold.

__The actions__

The actions of a rule can consists of one or more actions. Each action describes a command that 
should be executed when the condition of the rule is true. Take a look at the 
[actions.coffee](actions.html) for more details.
###

 
assert = require 'cassert'
util = require 'util'
Promise = require 'bluebird'
_ = require 'lodash'
S = require 'string'
M = require './matcher'
require "date-format-lite"
milliseconds = require './milliseconds'
rulesAst = require './rules-ast-builder'

module.exports = (env) ->


  class Rule
    id: null
    name: null
    string: null

    active: null
    valid: null
    logging: null

    # Condition as string
    conditionToken: null
    # Actions as string
    actionsToken: null

    # PredicateHandler
    predicates: null
    # Rule as tokens
    tokens: null
    # ActionHandler
    actions: null

    # Error message if not valid
    error: null
    # Time the rule was last executed
    lastExecuteTime: null

    conditionExprTree: null
      
    constructor: (@id, @name, @string) ->
      assert typeof @id is "string"
      assert typeof @name is "string"
      assert typeof @string is "string"

    update: (fromRule) ->
      assert @id is fromRule.id
      @name = fromRule.name
      @string = fromRule.string
      @active = fromRule.active
      @valid = fromRule.valid
      @logging = fromRule.logging
      @conditionToken = fromRule.conditionToken
      @actionsToken = fromRule.actionsToken
      @predicates = fromRule.predicates
      @tokens = fromRule.tokens
      @actions = fromRule.actions
      @error = fromRule.error
      @lastExecuteTime = fromRule.lastExecuteTime
      @conditionExprTree = fromRule.conditionExprTree

    toJson: -> {
      id: @id
      name: @name
      string: @string
      active: @active
      valid: @valid
      logging: @logging
      conditionToken: @conditionToken
      actionsToken: @actionsToken
      error: @error
    }

  ###
  The Rule Manager
  ----------------
  The Rule Manager holds a collection of rules. Rules can be added to this collection. When a rule
  is added, the rule is parsed by the Rule Manager and for each predicate a Predicate Provider will
  be searched. Predicate Provider that should be considered can be added to the Rule Manager.

  If all predicates of the added rule can be handled by a Predicate Provider, for each action of a
  rule's action an Action Handler is searched. Action Handler can be added to the
  Rule Manager, too.

  ###
  class RuleManager extends require('events').EventEmitter
    # Array of the added rules
    # If a rule was successfully added, the rule has the form:
    #  
    #     id: 'some-id'
    #     name: 'some name'
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

    # ###_parseRuleString()
    # This function parses a rule given by a string and returns a rule object.
    # A rule string is for example 'if its 10pm and light is on then turn the light off'
    # it get parsed to the follwoing rule object:
    #  
    #     id: 'some-id'
    #     string: 'when its 10pm and light is on then turn the light off'
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
    _parseRuleString: (id, name, ruleString, context) ->
      assert id? and typeof id is "string" and id.length isnt 0
      assert name? and typeof name is "string"
      assert ruleString? and typeof ruleString is "string"

      rule = new Rule(id, name, ruleString)
      # Always return a promise
      return Promise.try( =>
        
        ###
        First take the string apart, so that
         
            parts = ["", "its 10pm and light is on", "turn the light off"].
        
        ###
        parts = ruleString.split /^when\s|\sthen\s/
        # Check for the right parts count. Note the empty string at the beginning.
        switch
          when parts.length < 3
            throw new Error('The rule must start with "when" and contain a "then" part!')
          when parts.length > 3 
            throw new Error('The rule must exactly contain one "when" and one "then" part!')
        ###
        Then extract the condition and actions from the rule 
         
            rule.conditionToken = "its 10pm and light is on"
            rule.actions = "turn the light off"
         
        ###
        rule.conditionToken = parts[1].trim()
        rule.actionsToken = parts[2].trim()

        if rule.conditionToken.length is 0
          throw new Error("Condition part of rule #{id} is empty.")
        if rule.actionsToken.length is 0
          throw new Error("Actions part of rule #{id} is empty.")

        result = @_parseRuleCondition(id, rule.conditionToken, context)
        rule.predicates = result.predicates
        rule.tokens = result.tokens

        unless context.hasErrors()
          result = @_parseRuleActions(id, rule.actionsToken, context)
          rule.actions = result.actions
          rule.actionToken = result.tokens
          rule.conditionExprTree = (new rulesAst.BoolExpressionTreeBuilder())
            .build(rule.tokens, rule.predicates)
        return rule
      )

    _parseRuleCondition: (id, conditionString, context) ->
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
       
      ### 
      predicates = []
      tokens = []
      # For each token

      nextInput = conditionString

      success = yes
      openedParentheseCount = 0
      justCondition = false

      while (not context.hasErrors()) and nextInput.length isnt 0
        M(nextInput, context).matchOpenParenthese('[', (next, ptokens) =>
          tokens = tokens.concat ptokens
          openedParentheseCount += ptokens.length
          nextInput = next.getRemainingInput()
        )

        i = predicates.length
        predId = "prd-#{id}-#{i}"

        { predicate, token, nextInput } = @_parsePredicate(
          predId, nextInput, context, null, justCondition
        )
        unless context.hasErrors()
          predicates.push(predicate)
          tokens = tokens.concat ["predicate", "(", i, ")"]

          M(nextInput, context).matchCloseParenthese(']', openedParentheseCount, (next, ptokens) =>
            tokens = tokens.concat ptokens
            openedParentheseCount -= ptokens.length
            nextInput = next.getRemainingInput()
          )

          # Try to match " and ", " or ", ...
          possibleTokens = [' and if ', ' and ', ' or when ', ' or ']
          onMatch = (m, s) => 
            token = s.trim()
            if token is 'and if' then justCondition = true
            else if token is 'or when' then justCondition = false
            tokens.push token
          m = M(nextInput, context).match(possibleTokens, onMatch)
          unless nextInput.length is 0
            if m.hadNoMatch()
              context.addError("""Expected one of: "and", "or", "]".""")
            else
              token = m.getFullMatch()
              assert S(nextInput.toLowerCase()).startsWith(token.toLowerCase())
              nextInput = nextInput.substring(token.length)
      if tokens.length > 0
        lastToken = tokens[tokens.length-1]
        if lastToken in ["and", "or", "and if", "or when"]
          context.addError("""Expected a new predicate after last "#{lastToken}".""")
      if openedParentheseCount > 0
        context.addError("""Expected closing parenthese ("]") at end.""")
      return {
        predicates: predicates
        tokens: tokens
      }

    _parsePredicate: (predId, nextInput, context, predicateProviderClass, justCondition) =>
      assert typeof predId is "string" and predId.length isnt 0
      assert typeof nextInput is "string"
      assert context?

      predicate =
        id: predId
        token: null
        handler: null
        for: null
        justTrigger: false
        justCondition: justCondition

      token = ''

      # trigger keyword?
      m = M(nextInput, context).match(["trigger: "])
      if m.hadMatch()
        match = m.getFullMatch()
        token += match
        nextInput = nextInput.substring(match.length)
        predicate.justTrigger = match is "trigger: "

      # find a predicate provider for that can parse and decide the predicate:
      parseResults = []
      for predProvider in @predicateProviders
        if predicateProviderClass?
          continue if predProvider.constructor.name isnt predicateProviderClass
        context.elements = {}
        parseResult = predProvider.parsePredicate(nextInput, context)
        if parseResult?
          assert parseResult.token? and parseResult.token.length > 0
          assert parseResult.nextInput? and typeof parseResult.nextInput is "string"
          assert parseResult.predicateHandler?
          assert parseResult.predicateHandler instanceof env.predicates.PredicateHandler
          parseResult.elements = context.elements[parseResult.token]
          parseResults.push parseResult

      switch parseResults.length
        when 0
          context.addError(
            """Could not find an provider that decides next predicate of "#{nextInput}"."""
          )
        when 1
          # get part of nextInput that is related to the found provider
          parseResult = parseResults[0]
          token += parseResult.token
          assert parseResult.token?
          #assert S(nextInput.toLowerCase()).startsWith(parseResult.token.toLowerCase())
          predicate.token = parseResult.token
          nextInput = parseResult.nextInput
          predicate.handler = parseResult.predicateHandler
          context.elements = {}
          timeParseResult = @_parseTimePart(nextInput, " for ", context)
          if timeParseResult?
            token += timeParseResult.token
            nextInput = timeParseResult.nextInput
            predicate.for = {
              token: timeParseResult.timeToken
              exprTokens: timeParseResult.timeExprTokens
              unit: timeParseResult.unit
            }

          if predicate.justTrigger and predicate.for?
            context.addError(
              "\"#{token}\" is marked as trigger, it can't be true for \"#{predicate.token}\"."
            )

          if predicate.handler.getType() is 'event' and predicate.for?
            context.addError(
              "\"#{token}\" is an event it can't be true for \"#{predicate.for.token}\"."
            )

          if predicate.handler.getType() is 'event' and predicate.justCondition
            context.addError(
              "\"#{token}\" is an event it can't be used with \"... and if ...\"."
            )

        else
          context.addError(
            """Next predicate of "#{nextInput}" is ambiguous."""
          )
      return { 
        predicate, token, nextInput, 
        elements: parseResult?.elements 
        forElements: timeParseResult?.elements
      }

    _parseTimePart: (nextInput, prefixToken, context, options = null) ->
      # Parse the for-Suffix:
      timeExprTokens = null
      unit = null
      onTimeduration = (m, tp) => 
        timeExprTokens = tp.tokens
        unit = tp.unit

      varsAndFuns = @framework.variableManager.getVariablesAndFunctions()
      m = M(nextInput, context)
        .match(prefixToken, options)
        .matchTimeDurationExpression(varsAndFuns, onTimeduration)

      unless m.hadNoMatch()
        token = m.getFullMatch()
        assert S(nextInput).startsWith(token)
        timeToken = S(token).chompLeft(prefixToken).s
        nextInput = nextInput.substring(token.length)
        elements = m.elements
        return {token, nextInput, timeToken, timeExprTokens, unit, elements}
      else
        return null

    _parseRuleActions: (id, nextInput, context) ->
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
        { action, token, nextInput } = @_parseAction(actionId, nextInput, context)
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
            if m.hadNoMatch()
              context.addError("Expected: \"and\", got \"#{nextInput}\"")
            else
              token = m.getFullMatch()
              assert S(nextInput.toLowerCase()).startsWith(token.toLowerCase())
              nextInput = nextInput.substring(token.length)
      return {
        actions: actions
        tokens: tokens
      }

    _parseAction: (actionId, nextInput, context) =>
      assert typeof nextInput is "string"
      assert context?

      token = null

      action =
        id: actionId
        token: null
        handler: null
        after: null
        for: null

      parseAfter = (type) =>
        prefixToken =  (if type is "prefix" then "after " else " after ")
        timeParseResult = @_parseTimePart(nextInput, prefixToken, context)
        if timeParseResult?
          nextInput = timeParseResult.nextInput
          if type is 'prefix'
            if nextInput.length > 0 and nextInput[0] is ' '
              nextInput = nextInput.substring(1)
          action.after = {
            token: timeParseResult.timeToken
            exprTokens: timeParseResult.timeExprTokens
            unit: timeParseResult.unit
          }
      # Try to match after as prefix: after 10 seconds log "42" 
      parseAfter('prefix')

      # find a predicate provider for that can parse and decide the predicate:
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
          # Get part of nextInput that is related to the found provider
          parseResult = parseResults[0]
          token = parseResult.token
          assert token?
          assert S(nextInput.toLowerCase()).startsWith(parseResult.token.toLowerCase())
          action.token = token
          nextInput = parseResult.nextInput
          action.handler = parseResult.actionHandler

          # Try to match after as suffix: log "42" after 10 seconds
          unless action.after?
            parseAfter('suffix')

          # Try to parse "for 10 seconds"
          forSuffixAllowed = action.handler.hasRestoreAction()
          timeParseResult = @_parseTimePart(nextInput, " for ", context, {
            acFilter: () => forSuffixAllowed
          })
          if timeParseResult?
            nextInput = timeParseResult.nextInput
            action.for = {
              token: timeParseResult.timeToken
              exprTokens: timeParseResult.timeExprTokens
              unit: timeParseResult.unit
            }

          if action.for? and forSuffixAllowed is no
            context.addError(
              """Action "#{action.token}" can't have a "for"-Suffix."""
            )
          
        else
          context.addError(
            """Next action of "#{nextInput}" is ambiguous."""
          )

      return { action, token, nextInput }

    # This function should be called by a provider if a predicate becomes true.
    whenPredicateIsTrue: (rule, predicateId, state) =>
      assert rule?
      assert predicateId? and typeof predicateId is "string" and predicateId.length isnt 0
      assert state is 'event' or state is true

      # If not active, then nothing to do
      unless rule.active then return

      # Then mark the given predicate as true
      knownPredicates = {}
      knownPredicates[predicateId] = true

      # And check if the rule is now true.
      @_evaluateConditionOfRule(rule, knownPredicates).then( (isTrue) =>
        # If the rule is now true, then execute its action
        if isTrue 
          return @_executeRuleActionsAndLogResult(rule)
      ).catch( (error) => 
        env.logger.error """
          Error on evaluation of rule condition of rule #{rule.id}: #{error.message}
        """ 
        env.logger.debug error
      )
      return

    # ###_addPredicateChangeListener()
    # Register for every predicate the callback function that should be called
    # when the predicate becomes true.
    _addPredicateChangeListener: (rule) ->
      assert rule?
      assert rule.predicates?

      setupTime = (new Date()).getTime()
      # For all predicate providers
      for p in rule.predicates
        do (p) =>
          assert(not p.changeListener?)
          p.lastChange = setupTime
          p.handler.setup()
          if p.for
            p.timeAchived = false
          # Let us be notified when the predicate state changes.
          p.handler.on 'change', changeListener = (state) =>
            assert state is 'event' or state is true or state is false
            p.lastChange = (new Date()).getTime()
            # If the state is true then call the `whenPredicateIsTrue` function.
            unless p.justCondition
              if p.for?
                if state is false
                  clearTimeout(p.forTimeout)
                  p.forTimeout = undefined
                  p.timeAchived = false
                if state is true
                  # If timeout already set, -> return
                  if p.forTimeout? then return
                  @_evaluateTimeExpr(
                    p.for.exprTokens,
                    p.for.unit
                  ).then( (ms) =>
                    # If timeout already set, -> return
                    if p.forTimeout? then return
                    p.forTimeout = setTimeout( ( () =>
                      p.timeAchived = true
                      @whenPredicateIsTrue rule, p.id, state
                    ), ms)
                  ).catch( (err) =>
                    env.logger.error "Error evaluating time expr for predicate: #{err.message}"
                    env.logger.debug error
                  )
              else
                if state is true or state is 'event'
                  @whenPredicateIsTrue rule, p.id, state
          p.changeListener = changeListener
          if p.for?
            # bootstrap timeout
            p.handler.getValue().then( (val) =>
              if val is true
                if p.forTimeout? then return
                @_evaluateTimeExpr(
                  p.for.exprTokens,
                  p.for.unit
                ).then( (ms) =>
                  # If timeout already set, -> return
                  if p.forTimeout? then return
                  p.forTimeout = setTimeout( ( () =>
                    p.timeAchived = true
                  ), ms)
                )
            )

          p.handler.on 'recreate', recreateListener = =>
            @recreateRule(rule)
          p.ready = true

    _removePredicateChangeListener: (rule) ->
      assert rule?
      # Then cancel the notifier for all predicates
      if rule.valid
        for p in rule.predicates
          do (p) =>
            if p.ready
              assert typeof p.changeListener is "function"
              p.handler.removeListener 'change', p.changeListener
              delete p.changeListener
              p.handler.removeAllListeners 'recreate'
              p.handler.destroy()
              clearTimeout(p.forTimeout)
              p.ready = false

    _setupActions: (rule) ->
      for action in rule.actions
        action.handler.setup()
        action.handler.on 'recreate', recreateListener = =>
          @recreateRule(rule)
        action.ready = true


    _destroyActionsAndCancelSheduledActions: (rule) ->
      assert rule?
      # Then cancel the notifier for all predicates
      if rule.valid
        for action in rule.actions
          do (action) =>
            if action.ready
              action.handler.destroy()
              action.handler.removeAllListeners 'recreate'
              action.ready = false
              if action.scheduled?
                action.scheduled.cancel(
                  "canceling schedule of action #{action.token}"
                )

    # ###addRuleByString()
    addRuleByString: (id, {name, ruleString, active, logging}, force = false) ->
      assert id? and typeof id is "string" and id.length isnt 0
      assert name? and typeof name is "string"
      assert ruleString? and typeof ruleString is "string"
      assert (if active? then typeof active is "boolean" else true)
      assert (if logging? then typeof logging is "boolean" else true)
      assert (if force? then typeof force is "boolean" else true)
      unless active? then active = yes
      unless logging? then logging = yes


      unless id.match /^[a-z0-9\-_]+$/i then throw new Error "Rule ID must only contain " +
        "alpha numerical symbols, \"-\" and  \"_\""
      if @rules[id]? then throw new Error "There is already a rule with the ID \"#{id}\""

      context = @_createParseContext()
      # First parse the rule.
      return @_parseRuleString(id, name, ruleString, context).then( (rule) =>
        rule.logging = logging
        # If we have a parse error we don't need to continue here
        if context.hasErrors()
          error = new Error context.getErrorsAsString()
          error.rule = rule
          error.context = context
          throw error

        @_addPredicateChangeListener rule
        @_setupActions rule
        # If the rules was successful parsed add it to the rule array.
        rule.active = active
        rule.valid = yes
        @rules[id] = rule
        @emit "ruleAdded", rule
        return
      ).catch( (error) =>
        # If there was an error parsing the rule, but the rule is forced to be added, then add
        # the rule with an error.
        if force
          if error.rule?
            rule = error.rule
            rule.error = error.message
            rule.active = false
            rule.valid = no
            @rules[id] = rule
            @emit 'ruleAdded', rule
          else
            env.logger.error 'Could not force add rule, because error has no rule attribute.'
            env.logger.debug error.stack
        throw error
      )

    # ###removeRule()
    # Removes a rule from the Rule Manager.
    removeRule: (id) ->
      assert id? and typeof id is "string" and id.length isnt 0
      throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?

      # First get the rule from the rule array.
      rule = @rules[id]
      # Then cancel all notifications
      @_removePredicateChangeListener(rule)
      @_destroyActionsAndCancelSheduledActions(rule)
      # and delete the rule from the array
      delete @rules[id]
      # and emit the event.
      @emit "ruleRemoved", rule
      return

    # ###updateRuleByString()
    updateRuleByString: (id, {name, ruleString, active, logging}) ->
      assert id? and typeof id is "string" and id.length isnt 0
      assert (if name? then typeof name is "string" else true)
      assert (if ruleString? then typeof ruleString is "string" else true)
      assert (if active? then typeof active is "boolean" else true)
      assert (if logging? then typeof logging is "boolean" else true)
      throw new Error("Invalid ruleId: \"#{id}\"") unless @rules[id]?
      rule = @rules[id]
      unless name? then name = rule.name
      unless ruleString? then ruleString = rule.string
      context = @_createParseContext()
      # First try to parse the updated ruleString.
      return @_parseRuleString(id, name, ruleString, context).then( (newRule) =>
        if context.hasErrors()
          error = new Error context.getErrorsAsString()
          error.rule = newRule
          error.context = context
          throw error

        # Set the properties for the new rule
        newRule.valid = yes
        newRule.active = if active? then active else rule.active
        newRule.logging = if logging? then logging else rule.logging

        # If the rule was successfully parsed then update the rule
        if rule isnt @rules[id]
          throw new Error("Rule #{rule.id} was removed while updating")

        # and cancel the notifier for the old predicates.
        @_removePredicateChangeListener(rule)
        @_destroyActionsAndCancelSheduledActions(rule)

        # We do that to keep the old rule object and don't use the new one
        rule.update(newRule)

        # and register the new ones,
        @_addPredicateChangeListener(rule)
        @_setupActions(rule)
        # and emit the event.
        @emit "ruleChanged", rule
      )

    recreateRule: (rule) ->
      if rule.recreating
        return
      rule.recreating = true
      @updateRuleByString(rule.id, {})
        .then( => rule.recreating = false )
        .catch( (error) =>
          @_removePredicateChangeListener(rule)
          @_destroyActionsAndCancelSheduledActions(rule)
          rule.active = false
          rule.valid = false
          rule.recreating = false 
          env.logger.error("Error in rule #{rule.id}: #{error.message}")
          env.logger.debug(error.stack)
          # and emit the event.
          @emit "ruleChanged", rule
        ).done()


    # ###_evaluateConditionOfRule()
    # This function returns a promise that will be fulfilled with true if the condition of the 
    # rule is true. This function ignores all the "for"-suffixes of predicates. 
    # The `knownPredicates` is an object containing a value for
    # each predicate for that the state is already known.
    _evaluateConditionOfRule: (rule, knownPredicates = {}) ->
      assert rule? and rule instanceof Object
      assert knownPredicates? and knownPredicates instanceof Object
      return rule.conditionExprTree.evaluate(knownPredicates)

    # ###_executeRuleActionsAndLogResult()
    # Executes the actions of the string using `executeAction` and logs the result to 
    # the env.logger.    
    _executeRuleActionsAndLogResult: (rule) ->
      currentTime = (new Date).getTime()
      if rule.lastExecuteTime?
        delta = currentTime - rule.lastExecuteTime
        if delta <= 500
          env.logger.debug "Suppressing rule #{rule.id} execute because it was executed recently."
          return Promise.resolve()
      rule.lastExecuteTime = currentTime

      actionResults = @_executeRuleActions(rule, false)

      logMessageForResult = (actionResult) =>
        return actionResult.then( (result) =>
          [message, next] = (
            if typeof result is "string" then [result, null]
            else 
              assert Array.isArray result
              assert result.length is 2
              result
          )
          if rule.logging
            env.logger.info "rule #{rule.id}: #{message}"
          if next?
            assert next.then?
            next = logMessageForResult(next)
          return [message, next]
        ).catch( (error) =>
          env.logger.error "rule #{rule.id} error executing an action: #{error.message ? error}"
          env.logger.debug error.stack if error.stack?
        )

      for actionResult in actionResults
        actionResult = logMessageForResult(actionResult)
      return Promise.all(actionResults)

    # ###executeAction()
    # Executes the actions in the given actionString
    _executeRuleActions: (rule, simulate) ->
      assert rule?
      assert rule.actions?
      assert simulate? and typeof simulate is "boolean"

      actionResults = []
      for action in rule.actions
        do (action) =>
          promise = null
          if action.after?
            unless simulate 
              # Cancel schedule for pending executes
              if action.scheduled?
                action.scheduled.cancel(
                  "reschedule action #{action.token} in #{action.after.token}"
                ) 
              # Schedule new action
              promise = @_evaluateTimeExpr(
                action.after.exprTokens, 
                action.after.unit
              ).then( (ms) => @_scheduleAction(action, ms) )
            else
              promise = @_executeAction(action, simulate).then( (message) => 
                "#{message} after #{action.after.token}"
              )
          else
            promise = @_executeAction(action)
          assert promise.then?
          actionResults.push promise
      return actionResults

    _evaluateTimeExpr: (exprTokens, unit) =>
      @framework.variableManager.evaluateNumericExpression(exprTokens).then( (time) =>
        return milliseconds.parse "#{time} #{unit}"
      )

    _executeAction: (action, simulate) =>
      # wrap into an fcall to convert thrown erros to a rejected promise
      return Promise.try( => 
        promise = action.handler.executeAction(simulate)
        if action.for?
          promise = promise.then( (message) =>
            restoreActionPromise = @_evaluateTimeExpr(
              action.for.exprTokens, 
              action.for.unit
            ).then( (ms) => @_scheduleAction(action, ms, yes) )
            return [message, restoreActionPromise]
          )
        return promise
      )

    _executeRestoreAction: (action, simulate) =>
      # Wrap into an fcall to convert thrown erros to a rejected promise
      return Promise.try( => action.handler.executeRestoreAction(simulate) )

    _scheduleAction: (action, ms, isRestore = no) =>
      assert action?
      if action.scheduled?
        action.scheduled.cancel("clearing scheduled action")

      return new Promise( (resolve, reject) =>
        timeoutHandle = setTimeout((=> 
          promise = (
            unless isRestore then @_executeAction(action, no)
            else @_executeRestoreAction(action, no)
          )
          resolve(promise)
          delete action.scheduled
        ), ms)
        action.scheduled = {
          startDate: new Date()
          cancel: (reason) =>
            clearTimeout(timeoutHandle)
            delete action.scheduled
            resolve(reason)
        }
      )

    _createParseContext: ->
      {variables, functions} = @framework.variableManager.getVariablesAndFunctions()
      return M.createParseContext(variables, functions)

  
    # ###getRules()
    getRules: () -> 
      rules = (r for id, r of @rules)
      # sort in config order
      rulesInConfig = _.map(@framework.config.rules, (r) => r.id )
      return _.sortBy(rules, (r) => rulesInConfig.indexOf r.id )

    getRuleById: (ruleId) -> @rules[ruleId]

    getRuleActionsHints: (actionsInput) ->
      context =  null
      result = null

      context = @_createParseContext()
      result = @_parseRuleActions("id", actionsInput, context)
      context.finalize()

      for a in result.actions
        delete a.handler

      return {
        tokens: result.tokens
        actions: result.actions
        autocomplete: context.autocomplete
        errors: context.errors
        format: context.format
        warnings: context.warnings
      }

    getRuleConditionHints: (conditionInput) ->
      context =  null
      result = null

      context = @_createParseContext()
      result = @_parseRuleCondition("id", conditionInput, context)
      context.finalize()

      for p in result.predicates
        delete p.handler

      tree = null
      if context.errors.length is 0
        tree = (new rulesAst.BoolExpressionTreeBuilder())
          .build(result.tokens, result.predicates)

      return {
        tokens: result.tokens
        predicates: result.predicates
        tree: tree
        autocomplete: context.autocomplete
        errors: context.errors
        format: context.format
        warnings: context.warnings
      }

    getPredicatePresets: () ->
      presets = []
      for p in @predicateProviders
        if p.presets?
          for d in p.presets
            d.predicateProviderClass = p.constructor.name
            presets.push d
      return presets


    getPredicateInfo: (input, predicateProviderClass) ->
      context = @_createParseContext()
      result = @_parsePredicate("id", input, context, predicateProviderClass, false)
      if result?.predicate?
        unless result.predicate.justTrigger or result.predicate.handler?.getType() is "event"
          unless result.forElements?
            timeParseResult = @_parseTimePart(" for 5 minutes", " for ", context)
            result.forElements = timeParseResult.elements
        delete result.predicate.handler
      context.finalize()
      result.errors = context.errors
      return result

    executeAction: (actionString, simulate = false, logging = yes) =>
      context = @_createParseContext()
      parseResult = @_parseAction('custom-action', actionString, context)
      context.finalize()
      if context.hasErrors()
        return Promise.reject new Error(context.errors)
      return @_executeAction(parseResult.action, simulate).then( (message) =>
        env.logger.info "execute action: #{message}" if logging
        return message
      )

    updateRuleOrder: (ruleOrder) ->
      assert ruleOrder? and Array.isArray ruleOrder
      @framework.config.rules = _.sortBy(@framework.config.rules,  (rule) => 
        index = ruleOrder.indexOf rule.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @framework.saveConfig()
      @framework._emitRuleOrderChanged(ruleOrder)
      return ruleOrder

  return exports = { RuleManager }
