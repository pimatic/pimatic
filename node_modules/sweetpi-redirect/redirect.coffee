modules = require '../../lib/modules'

class RedirectFrontend extends modules.Frontend

  init: (app, server, @config) =>
    _this = this

    for route in config.routes
      app.get route.path, (req, res, next) ->
        res.redirect route.redirect

module.exports = new RedirectFrontend