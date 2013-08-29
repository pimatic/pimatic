express = require "express" 
coffeescript = require 'connect-coffee-script'
modules = require '../../lib/modules'
socketIo = require 'socket.io'
logger = require '../../lib/logger'

class MobileFrontend extends modules.Frontend
  config: null

  init: (app, server, @config) =>
    thisClass = @;

    app.use coffeescript(
      src: __dirname + "/coffee",
      dest: __dirname + '/public/js',
      bare: true
    )

    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'

    actuators = (server.getActuatorById(a.id) for a in config.actuatorsToDisplay)

    app.get '/', (req,res) ->
      res.render 'index',
        actuators: actuators
        theme: 
          cssFiles: ['themes/graphite/generated/water/jquery.mobile-1.3.1.css']
      
    app.use express.static(__dirname + "/public")

    # For every webserver
    for webServer in [app.httpServer, app.httpsServer]
      continue unless webServer?
      # Listen for new websocket connections
      io = socketIo.listen webServer, {logger: logger}
      # When a new client connects
      io.sockets.on 'connection', (socket) ->
        for actuator in actuators 
          do (actuator) ->
            # * First time push the state to the client
            actuator.getState (error, state) ->
              unless error? then thisClass.emitSwitchState socket, actuator, state
            # * Then forward following state event to the client
            actuator.on "state", (state) ->
              thisClass.emitSwitchState socket, actuator, state

  emitSwitchState: (socket, actuator, state) ->
    socket.emit "switch-status",
      id: actuator.id
      state: state

module.exports = new MobileFrontend