__ = require('i18n').__
Q = require 'q'

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
            actuator[req.params.actionName]().then( ->
              res.send 200, null
            ).catch( (e) ->
              env.logger.error e.message
              env.logger.debug e.stack
              res.send 500, e.message
            ).done()
          else
            res.send 400, 'illegal action!'
        else res.send 400, 'illegal actuator!'

      app.post "/api/rule/:ruleId/update", (req, res, next) ->
        ruleId = req.params.ruleId
        ruleText = req.body.rule
        error = null
        try
          server.ruleManager.updateRuleByString(ruleId, ruleText).done()
        catch e
          env.logger.error e.message
          env.logger.debug e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

      app.post "/api/rule//add", (req, res, next) ->
        res.send 200, {success: false, error: __('Please enter a id')}
        
      app.post "/api/rule/:ruleId/add", (req, res, next) ->
        ruleId = req.params.ruleId
        ruleText = req.body.rule
        server.ruleManager.addRuleByString(ruleId, ruleText).then(
          res.send 200, {success: true}  
        ).catch( (e) ->
          env.logger.debug e.stack
          res.send 200, {success: false, error: error.message}
        ).done()

      app.get "/api/rule/:ruleId/remove", (req, res, next) ->
        ruleId = req.params.ruleId
        error = null
        try
          server.ruleManager.removeRule ruleId
        catch e
          env.logger.debug e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

      app.get "/api/messages", (req, res, next) ->
        memoryTransport = env.logger.transports.memory
        res.send 200, memoryTransport.getBuffer()

        
  return new RestFrontend