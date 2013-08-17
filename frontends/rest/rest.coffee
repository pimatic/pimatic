modules = require '../../lib/modules'

class RestFrontend extends modules.Frontend
  config: null

  init: (app, server, config) =>
    @config = config
    app.get "/api/actor/:actorId/:actionName", (req, res, next) ->
      actor = server.getActorById req.params.actorId
      if actor?
        #TODO: add parms support
        if actor.hasAction req.params.actionName
          fun = actor[req.params.actionName]
          fun.apply actor, [(e) ->
            res.send 200, e
          ]
        else
          res.send 400, 'illegal action!'
      else res.send 400, 'illegal actor!'
      
module.exports = new RestFrontend