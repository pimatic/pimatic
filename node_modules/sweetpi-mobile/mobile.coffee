# #The mobile frontend
# Displays a [jQuery mobile](http://jquerymobile.com/) page, witch let you control
# switch-Actuators and add rules. 
# 
# ##Example config:
# 
#     {
#       "module": "mobile",
#       "actuatorsToDisplay": [
#         { "id": "light" },
#         { "id": "printer" }
#       ]
#     }
 
# ##Dependencies
express = require "express" 
coffeescript = require 'connect-coffee-script'
modules = require '../../lib/modules'
socketIo = require 'socket.io'
logger = require '../../lib/logger'
async = require 'async'

# ##The MobileFrontend
class MobileFrontend extends modules.Frontend
  server: null
  config: null

  # ###init the frontend:
  init: (app, @server, @config) =>
    self = @

    # * Get all actuatorsToDisplay from config:
    self.actuators = (server.getActuatorById(a.id) for a in config.actuatorsToDisplay)

    # * Setup the coffeescript compiler
    app.use coffeescript(
      prefix: '/js'
      src: __dirname + "/coffee",
      dest: __dirname + '/public/js',
      bare: true,
      force: true
    )

    # * Setup jade-templates
    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'

    # * Delivers the index-page
    app.get '/', (req,res) ->
      res.render 'index',
        theme: 
          cssFiles: ['themes/graphite/generated/water/jquery.mobile-1.3.1.css']

    # * Delivers json-Data in the form of:

    # 
    #     {
    #       "actuators": [
    #         { "id": "light",
    #           "name": "Schreibtischlampe",
    #           "state": null },
    #           ...
    #       ], "rules": [
    #         { "id": "printerOff",
    #           "condition": "its 6pm",
    #           "action": "turn the printer off" },
    #           ...
    #       ]
    #     }
    # 
    app.get '/data.json', (req,res) ->
      self.getActuatorDataWithState (error, actuators) ->
        rules = []
        for id of server.ruleManager.rules
          rule = server.ruleManager.rules[id]
          rules.push
            id: id
            condition: rule.orgCondition
            action: rule.action
        res.send 
          actuators: actuators
          rules: rules

    # * Static assets
    app.use express.static(__dirname + "/public")

    # ###Socket.io stuff:
    # For every webserver
    for webServer in [app.httpServer, app.httpsServer]
      continue unless webServer?
      # Listen for new websocket connections
      io = socketIo.listen webServer, {logger: logger}
      # When a new client connects
      io.sockets.on 'connection', (socket) ->
        cleanUpFunctions = []
        for actuator in self.actuators 
          do (actuator) ->
            # * First time push the state to the client
            actuator.getState (error, state) ->
              unless error? then self.emitSwitchState socket, actuator, state
            # * Then forward following state event to the client
            actuator.on "state", stateListener = (state) ->
              self.emitSwitchState socket, actuator, state
            
            cleanUpFunctions.push (-> actuator.removeListener "state", stateListener)
        server.ruleManager.on "add", addRuleListener = (rule) ->
          self.emitRuleUpdate socket, "add", rule
        cleanUpFunctions.push (-> server.ruleManager.removeListener "add", addRuleListener)       
        server.ruleManager.on "update", updateRuleListener = (rule) ->
          self.emitRuleUpdate socket, "update", rule
        cleanUpFunctions.push (-> server.ruleManager.removeListener "update", updateRuleListener)  
        server.ruleManager.on "remove", removeRuleListener = (rule) ->
          self.emitRuleUpdate socket, "remove", rule
        cleanUpFunctions.push (-> server.ruleManager.removeListener "update", removeRuleListener)  
        # On `close` remove all event listeners
        socket.on 'close', ->
          cleanUpFunction() for cleanUpFunction in cleanUpFunctions

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

  emitRuleUpdate: (socket, trigger, rule) ->
    socket.emit "rule-#{trigger}",
      id: rule.id
      condition: rule.orgCondition
      action: rule.action


module.exports = new MobileFrontend