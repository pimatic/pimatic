modules = require '../../lib/modules'

class RestFrontend extends modules.Frontend
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
        error = e
      res.send 200, {success: not error?, error: error?.message}

      
module.exports = new RestFrontend