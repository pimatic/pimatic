assert = require 'cassert'
fs = require "fs"
async = require 'async'
convict = require 'convict'
i18n = require 'i18n'
express = require "express"
Q = require 'q'

module.exports = (env) ->

  class Framework extends require('events').EventEmitter
    configFile: null
    plugins: []
    actuators: []
    sensors: []
    app: null
    ruleManager: null
    pluginManager: null
    config: null

    constructor: (@configFile) ->
      assert configFile?

      self = this
      self.loadConfig()

      self.ruleManager = new env.rules.RuleManager self, self.config.rules
      self.pluginManager = new env.plugins.PluginManager self

      self.setupExpressApp()

    loadConfig: () ->
      self = this
      # * Uses `node-convict` for config loading. All config options are in the 
      #   [config-shema](config-shema.html) file.
      conf = convict require("../config-shema")
      
      conf.loadFile self.configFile
      # * Performs the validation.
      conf.validate()
      self.config = conf.get("")

      env.helper.checkConfig env, null, ->
        assert Array.isArray self.config.plugins
        assert Array.isArray self.config.actuators
        assert Array.isArray self.config.rules

      # * Set the log level
      env.logger.transports.console.level = self.config.settings.logLevel

      i18n.configure({
        locales:['en', 'de'],
        directory: __dirname + '/../locales',
        defaultLocale: self.config.settings.locale,
      })


    setupExpressApp: () ->
      self = this
      # Setup express
      # -------------
      self.app = express()
      self.app.use i18n.init
      #self.app.use express.logger()
      self.app.use express.bodyParser()

      # Setup authentication
      # ----------------------
      # Use http-basicAuth if authentication is not disabled.
      auth = self.config.settings.authentication
      if auth.enabled
        #Check authentication.
        env.helper.checkConfig env, 'settings.authentication', ->
          assert auth.username and typeof auth.username is "string" and auth.username.length isnt 0 
          assert auth.password and typeof auth.password is "string" and auth.password.length isnt 0 
        self.app.use express.basicAuth(auth.username, auth.password)

      if not self.config.settings.httpsServer?.enabled and 
         not self.config.settings.httpServer?.enabled
        env.logger.warn "You have no https and no http server enabled!"

      # Start the https-server if it is enabled.
      if self.config.settings.httpsServer?.enabled
        httpsConfig = self.config.settings.httpsServer
        env.helper.checkConfig env, 'server', ->
          assert httpsConfig instanceof Object
          assert typeof httpsConfig.keyFile is 'string' and httpsConfig.keyFile.length isnt 0
          assert typeof httpsConfig.certFile is 'string' and httpsConfig.certFile.length isnt 0 

        httpsOptions = {}
        httpsOptions[name]=value for name, value of httpsConfig
        httpsOptions.key = fs.readFileSync httpsConfig.keyFile
        httpsOptions.cert = fs.readFileSync httpsConfig.certFile
        https = require "https"
        self.app.httpsServer = https.createServer httpsOptions, self.app

      # Start the http-server if it is enabled.
      if self.config.settings.httpServer?.enabled
        http = require "http"
        self.app.httpServer = http.createServer self.app

    listen: () ->
      self = this
      genErrFunc = (serverConfig) -> 
        return (err) ->
          msg = "Could not listen on port #{serverConfig.port}. " + 
                "Error: #{err.message}. "
          switch err.message 
            when "listen EACCES" then  msg += "Are you root?."
            when "listen EADDRINUSE" then msg += "Is a server already running?"
            else msg = null
          if msg?
            env.logger.error msg
            env.logger.debug err.stack  
          else throw err
          process.exit 1

      if self.app.httpsServer?
        httpsServerConfig = self.config.settings.httpsServer
        self.app.httpsServer.on 'error', genErrFunc(self.config.settings.httpsServer)
        self.app.httpsServer.listen httpsServerConfig.port
        env.logger.info "listening for https-request on port #{httpsServerConfig.port}..."

      if self.app.httpServer?
        httpServerConfig = self.config.settings.httpServer
        self.app.httpServer.on 'error', genErrFunc(self.config.settings.httpServer)
        self.app.httpServer.listen httpServerConfig.port
        env.logger.info "listening for http-request on port #{httpServerConfig.port}..."

      self.emit "server listen", "startup"

    loadPlugins: ->
      self = this 
      deferred = Q.defer()
      async.mapSeries(self.config.plugins, (pConf, cb)->
        assert pConf?
        assert pConf instanceof Object
        assert pConf.plugin? and typeof pConf.plugin is "string" 

        env.logger.info "loading plugin: \"#{pConf.plugin}\"..."
        plugin = self.pluginManager.loadPlugin env, "pimatic-#{pConf.plugin}", (err, plugin) ->
          cb(err, {plugin: plugin, config: pConf})
      , (err, plugins) ->
        self.registerPlugin(p.plugin, p.config) for p in plugins
        if err then deferred.reject err
        else deferred.resolve()
      )
      return deferred.promise


    registerPlugin: (plugin, config) ->
      assert plugin? and plugin instanceof env.plugins.Plugin
      assert config? and config instanceof Object

      @plugins.push {plugin: plugin, config: config}
      @emit "plugin", plugin

    registerActuator: (actuator) ->
      assert actuator?
      assert actuator instanceof env.actuators.Actuator
      assert actuator.name? and actuator.name.lenght isnt 0
      assert actuator.id? and actuator.id.lenght isnt 0

      if @actuators[actuator.id]?
        throw new assert.AssertionError("dublicate actuator id \"#{actuator.id}\"")

      env.logger.info "new actuator \"#{actuator.name}\"..."
      @actuators[actuator.id]=actuator
      @emit "actuator", actuator

    registerSensor: (sensor) ->
      assert sensor?
      assert sensor instanceof env.sensors.Sensor
      assert sensor.name? and sensor.name.lenght isnt 0
      assert sensor.id? and sensor.id.lenght isnt 0

      if @sensors[sensor.id]?
        throw new assert.AssertionError("dublicate sensor id \"#{sensor.id}\"")

      env.logger.info "new sensor \"#{sensor.name}\"..."
      @sensors[sensor.id]=sensor
      @emit "sensor", sensor

    loadActuators: ->
      for acConfig in @config.actuators
        found = false
        for plugin in @plugins
          if plugin.plugin.createActuator?
            found = plugin.plugin.createActuator acConfig
            if found then break
        unless found
          env.logger.warn "no plugin found for actuator \"#{acConfig.id}\"!"

    getActuatorById: (id) ->
      @actuators[id]

    getSensorById: (id) ->
      @sensors[id]

    init: ->
      self = this

      initPlugins = ->
        for plugin in self.plugins
          try
            plugin.plugin.init(self.app, self, plugin.config)
          catch err
            env.logger.error "Could not initialize the plugin \"#{plugin.config.plugin}\": " +
              err.message
            env.logger.debug err.stack

      initActionHandler = ->
        self.ruleManager.actionHandlers.push new env.actions.SwitchActionHandler self
        self.ruleManager.actionHandlers.push new env.actions.LogActionHandler self

      initRules = ->
        for rule in self.config.rules
          try
            self.ruleManager.addRuleByString(rule.id, rule.rule).done()
          catch err
            env.logger.error "Could not parse rule \"#{rule.rule}\": " + err.message 
            env.logger.debug err.stack        

        # Save rule updates to the config file:
        # 
        # * If a new rule was added then...
        self.ruleManager.on "add", (rule) ->
          # ...add it to the rules Array in the config.json file
          for r in self.config.rules 
            if r.id is rule.id then return
          self.config.rules.push 
            id: rule.id
            rule: rule.string
          self.emit "config"
        # * If a rule was changed then...
        self.ruleManager.on "update", (rule) ->
          # ...change the rule with the right id in the config.json file
          self.config.rules = for r in self.config.rules 
            if r.id is rule.id then {id: rule.id, rule: rule.string}
            else r
          self.emit "config"
        # * If a rule was removed then
        self.ruleManager.on "remove", (rule) ->
          # ...Remove the rule with the right id in the config.json file
          self.config.rules = (r for r in self.config.rules when r.id isnt rule.id)
          self.emit "config"

      return self.loadPlugins()
        .then(initPlugins)
        .then(-> self.loadActuators())
        .then(initActionHandler)
        .then(initRules)
        .then(->         
          # Save the config on "config" event
          self.on "config", ->
            self.saveConfig()

          self.emit "after init", "framework"
          self.listen()
        )

    saveConfig: ->
      self = this
      if self.config?
        fs.writeFile self.configFile, JSON.stringify(self.config, null, 2), (err) ->
          if err? then throw err
          else env.logger.info "config.json updated"