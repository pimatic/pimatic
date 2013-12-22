__ = require('i18n').__
Q = require 'q'

module.exports = (env) ->

  class RestFrontend extends env.plugins.Plugin
    config: null

    init: (app, framework, config) =>
      @config = config
      app.get "/api/actuator/:actuatorId/:actionName", (req, res, next) ->
        actuator = framework.getActuatorById req.params.actuatorId
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
          framework.ruleManager.updateRuleByString(ruleId, ruleText).done()
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
        framework.ruleManager.addRuleByString(ruleId, ruleText).then(
          res.send 200, {success: true}  
        ).catch( (e) ->
          env.logger.debug e.stack
          res.send 200, {success: false, error: error.message}
        ).done()

      app.get "/api/rule/:ruleId/remove", (req, res, next) ->
        ruleId = req.params.ruleId
        error = null
        try
          framework.ruleManager.removeRule ruleId
        catch e
          env.logger.debug e.stack
          error = e
        res.send 200, {success: not error?, error: error?.message}

      app.get "/api/messages", (req, res, next) ->
        memoryTransport = env.logger.transports.memory
        res.send 200, memoryTransport.getBuffer()

      app.get "/api/list/actuators", (req, res, next) ->
        actuatorList = for id, a of framework.actuators 
          id: a.id, name: a.name
        res.send 200, {success: true, actuators: actuatorList}

      app.get "/api/list/sensors", (req, res, next) ->
        sensorList = for id, s of framework.sensors 
          id: s.id, name: s.name
        res.send 200, {success: true, sensors: sensorList}

        
  return new RestFrontend