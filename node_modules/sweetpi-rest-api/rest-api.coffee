__ = require('i18n').__

module.exports = (env) ->

  class RestFrontend extends env.plugins.Plugin
    config: null

    init: (app, server, config) =>
      @config = config
      app.get "/api/actuator/:actuatorId/:actionName", (req, res, next) ->
        actuator = server.getActuatorById req.params.actuatorId
        if actuator?
          #TODO: add parms support
          if actuator.hasAction req.params.actionName
            fun = actuator[req.params.actionName]
            fun.apply actuator, [(e) ->
              res.send 200, e
            ]
          else
            res.send 400, 'illegal action!'
        else res.send 400, 'illegal actuator!'

      app.post "/api/rule/:ruleId/update", (req, res, next) ->
        ruleId = req.params.ruleId
        ruleText = req.body.rule
        error = null
        try
          server.ruleManager.updateRuleByString ruleId, ruleText
        catch e
          #console.log e
          console.log e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

      app.post "/api/rule//add", (req, res, next) ->
        res.send 200, {success: false, error: __('Please enter a id')}
      app.post "/api/rule/:ruleId/add", (req, res, next) ->
        ruleId = req.params.ruleId
        ruleText = req.body.rule
        error = null
        try
          server.ruleManager.addRuleByString ruleId, ruleText
        catch e
          #console.log e
          console.log e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

      app.get "/api/rule/:ruleId/remove", (req, res, next) ->
        ruleId = req.params.ruleId
        error = null
        try
          server.ruleManager.removeRule ruleId
        catch e
          #console.log e
          console.log e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

        
  return new RestFrontend