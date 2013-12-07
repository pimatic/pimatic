# ##Dependencies
express = require "express" 
coffeescript = require 'connect-coffee-script'
socketIo = require 'socket.io'
async = require 'async'
assert = require 'cassert'

module.exports = (env) ->

  # ##The MobileFrontend
  class MobileFrontend extends env.plugins.Plugin
    server: null
    config: null

    # ###init the frontend:
    init: (app, @server, @config) =>
      self = @

      # * Setup the coffeescript compiler
      app.use coffeescript(
        prefix: '/js'
        src: __dirname + "/coffee",
        dest: __dirname + '/public/js',
        bare: true,
        force: true
      )

      # * Setup jade-templates
      app.engine 'jade', require('jade').__express
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
      #       "items": [
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
        self.getItemsWithData (error, items) ->
          rules = []
          for id of server.ruleManager.rules
            rule = server.ruleManager.rules[id]
            rules.push
              id: id
              condition: rule.orgCondition
              action: rule.action
          res.send 
            items: items
            rules: rules

      # * Static assets
      app.use express.static(__dirname + "/public")

      # ###Socket.io stuff:
      # For every webserver
      for webServer in [app.httpServer, app.httpsServer]
        continue unless webServer?
        # Listen for new websocket connections
        io = socketIo.listen webServer, {logger: env.logger}
        # When a new client connects
        io.sockets.on 'connection', (socket) ->
          cleanUpFunc = []

          for item in self.config.items 
            do (item) ->
              if item.type is "actuator" 
                actuator = self.server.getActuatorById item.id
                if actuator?
                  # * First time push the state to the client
                  actuator.getState (error, state) ->
                    unless error? then self.emitSwitchState socket, actuator, state
                  # * Then forward following state event to the client
                  actuator.on "state", stateListener = (state) ->
                    self.emitSwitchState socket, actuator, state
                  socket.on 'close', -> actuator.removeListener "state", stateListener 
              
          server.ruleManager.on "add", addRuleListener = (rule) ->
            self.emitRuleUpdate socket, "add", rule
          
          server.ruleManager.on "update", updateRuleListener = (rule) ->
            self.emitRuleUpdate socket, "update", rule
         
          server.ruleManager.on "remove", removeRuleListener = (rule) ->
            self.emitRuleUpdate socket, "remove", rule

          socket.on 'close', -> 
            server.ruleManager.removeListener "update", updateRuleListener
            server.ruleManager.removeListener "add", addRuleListener 
            server.ruleManager.removeListener "update", removeRuleListener

    getItemsWithData: (cbWithData) ->
      self = this

      async.map(self.config.items, (item, callback) ->
        switch item.type
          when "actuator"
            self.getActuatorWithData item, callback
          else
            errorMsg = "Unknown item type \"#{item.type}\""
            env.logger.error 
            callback null, null
      , (err, items) -> 
        # filter `null` items
        if items? then items = (item for item in items when item?)
        console.log items
        cbWithData err, items
      )

    getActuatorWithData: (item, callback) ->
      self = this
      assert item.id?
      actuator = self.server.getActuatorById item.id
      if actuator?
        if actuator instanceof env.actuators.SwitchActuator
          actuator.getState (err, state) ->
            callback null,
              type: "actuator"
              template: "switch"
              id: actuator.id
              name: actuator.name
              state: (if error? or not state? then null else state)
        else 
          callback null,
            type: "actuator"
            id: actuator.id
            name: actuator.name
      else
        errorMsg = "No actuator to display with id \"#{item.id}\" found"
        env.logger.error errorMsg
        callback null,
          type: "actuator"
          id: item.id
          name: "Unknown"
          state: null,
          error: errorMsg


    emitSwitchState: (socket, actuator, state) ->
      socket.emit "switch-status",
        id: actuator.id
        state: state

    emitRuleUpdate: (socket, trigger, rule) ->
      socket.emit "rule-#{trigger}",
        id: rule.id
        condition: rule.orgCondition
        action: rule.action

  return new MobileFrontend