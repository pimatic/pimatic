# ##Dependencies
express = require "express" 
coffeescript = require 'connect-coffee-script'
socketIo = require 'socket.io'
async = require 'async'
assert = require 'cassert'
Q = require 'q'

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
        self.getItemsWithData().then( (items) ->
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
        ).done()

      # * Static assets
      app.use express.static(__dirname + "/public")

      # ###Socket.io stuff:
      # For every webserver
      for webServer in [app.httpServer, app.httpsServer]
        continue unless webServer?
        # Listen for new websocket connections
        io = socketIo.listen webServer, {
          logger: 
            log: (type, args...) ->
              if type isnt 'debug' then env.logger.log(type, 'socket.io:', args...)
            debug: (args...) -> @log('debug', args...)
            info: (args...) -> @log('info', args...)
            warn: (args...) -> @log('warn', args...)
            error: (args...) -> @log('error', args...)
        }

        # When a new client connects
        io.sockets.on 'connection', (socket) ->

          for item in self.config.items 
            do (item) ->
              switch item.type
                when "actuator" 
                  self.addActiatorNotify socket, item
                when 'sensor'
                  self.addSensorNotify socket, item
              
          server.ruleManager.on "add", addRuleListener = (rule) ->
            self.emitRuleUpdate socket, "add", rule
          
          server.ruleManager.on "update", updateRuleListener = (rule) ->
            self.emitRuleUpdate socket, "update", rule
         
          server.ruleManager.on "remove", removeRuleListener = (rule) ->
            self.emitRuleUpdate socket, "remove", rule

          memoryTransport = env.logger.transports.memory
          memoryTransport.on 'log', logListener = (entry)->
            socket.emit 'log', entry

          socket.on 'close', -> 
            server.ruleManager.removeListener "update", updateRuleListener
            server.ruleManager.removeListener "add", addRuleListener 
            server.ruleManager.removeListener "update", removeRuleListener
            memoryTransport.removeListener 'log', logListener
      return


    addActiatorNotify: (socket, item) ->
      actuator = @server.getActuatorById item.id
      if actuator?
        # * First time push the state to the client
        actuator.getState().then( (state) =>
          @emitSwitchState socket, actuator, state
        ).catch( (error) =>
          env.logger.error error.message
          env.logger.debug error.stack 
        )
        # * Then forward following state event to the client
        actuator.on "state", stateListener = (state) =>
          @emitSwitchState socket, actuator, state
        socket.on 'close', => actuator.removeListener "state", stateListener
      return

    addSensorNotify: (socket, item) ->
      sensor = @server.getSensorById item.id
      if sensor?
        names = sensor.getSensorValuesNames()
        for name in names 
          do (name) =>
            sensor.on name, (value) =>
              @emitSensorValue socket, sensor, name, value
            socket.on 'close', => sensor.removeListener name, valueListener
      return

    getItemsWithData: () ->
      self = this

      items = []
      for item in self.config.items
        switch item.type
          when "actuator"
            items.push self.getActuatorWithData item
          when "sensor"
            items.push self.getSensorWithData item
          else
            errorMsg = "Unknown item type \"#{item.type}\""
            env.logger.error errorMsg
      return Q.all items

    getActuatorWithData: (item) ->
      self = this
      assert item.id?
      actuator = self.server.getActuatorById item.id
      if actuator?
        item =
          type: "actuator"
          id: actuator.id
          name: actuator.name
          state: null
        if actuator instanceof env.actuators.SwitchActuator
          item.template = "switch"
          return actuator.getState().then( (state) ->
            item.state = state
            return item
          ).catch( (error) ->
            env.logger.error error.message
            env.logger.debug error.stack
            return item
          ) 
        else 
          return Q.fcall -> item
      else
        errorMsg = "No actuator to display with id \"#{item.id}\" found"
        env.logger.error errorMsg
        return Q.fcall ->
          type: "actuator"
          id: item.id
          name: "Unknown"
          state: null,
          error: errorMsg

    getSensorWithData: (item) ->
      self = this
      assert item.id?
      sensor = self.server.getSensorById item.id
      if sensor?
        item =
          type: "sensor"
          id: sensor.id
          name: sensor.name
          values: {}
        if sensor instanceof env.sensors.TemperatureSensor
          item.template = "temperature"
          nameValues = []
          for name in sensor.getSensorValuesNames()
            do (name) ->
              nameValues.push sensor.getSensorValue(name).then (value) ->
                return name: name, value: value
          return Q.all(nameValues).then( (nameValues)->
            for nameValue in nameValues
              item.values[nameValue.name] = nameValue.value
            return item
          ).catch( (error) ->
            env.logger.error error.message
            env.logger.debug error.stack
            return item
          ) 
        else 
          return Q.fcall -> item
      else
        errorMsg = "No sensor to display with id \"#{item.id}\" found"
        env.logger.error errorMsg
        return Q.fcall ->
          type: "sensor"
          id: item.id
          name: "Unknown"
          values: null,
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

    emitSensorValue: (socket, sensor, name, value) ->
      socket.emit "sensor-value",
        id: sensor.id
        name: name
        value: value

  return new MobileFrontend