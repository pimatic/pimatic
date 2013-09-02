express = require "express" 
coffeescript = require 'connect-coffee-script'
modules = require '../../lib/modules'
socketIo = require 'socket.io'
logger = require '../../lib/logger'
async = require 'async'

class MobileFrontend extends modules.Frontend
  server: null
  config: null

  init: (app, @server, @config) =>
    thisClass = @;

    app.use coffeescript(
      prefix: '/js'
      src: __dirname + "/coffee",
      dest: __dirname + '/public/js',
      bare: true,
      force: true
    )

    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'

    app.get '/', (req,res) ->
      res.render 'index',
        theme: 
          cssFiles: ['themes/graphite/generated/water/jquery.mobile-1.3.1.css']

    thisClass.actuators = (server.getActuatorById(a.id) for a in config.actuatorsToDisplay)

    app.get '/data.json', (req,res) ->
      thisClass.getActuatorDataWithState (error, actuators) ->
        rules = []
        for id of server.ruleManager.rules
          rule = server.ruleManager.rules[id]
          console.log rule
          rules.push
            id: id
            condition: rule.orgCondition
            action: rule.action
        res.send 
          actuators: actuators
          rules: rules

    app.use express.static(__dirname + "/public")

    # For every webserver
    for webServer in [app.httpServer, app.httpsServer]
      continue unless webServer?
      # Listen for new websocket connections
      io = socketIo.listen webServer, {logger: logger}
      # When a new client connects
      io.sockets.on 'connection', (socket) ->
        for actuator in thisClass.actuators 
          do (actuator) ->
            # * First time push the state to the client
            actuator.getState (error, state) ->
              unless error? then thisClass.emitSwitchState socket, actuator, state
            # * Then forward following state event to the client
            actuator.on "state", (state) ->
              thisClass.emitSwitchState socket, actuator, state

  getActuatorDataWithState: (callback) ->
    async.map( @actuators, (a, callback) ->
      a.getState (err, state) ->
        callback null,
          id: a.id
          name: a.name
          state: (if error? or not state? then null else state)
    , callback)


  emitSwitchState: (socket, actuator, state) ->
    socket.emit "switch-status",
      id: actuator.id
      state: state

module.exports = new MobileFrontend