assert = require 'cassert'
fs = require "fs"
convict = require 'convict'
i18n = require 'i18n'
express = require "express"
Q = require 'q'
path = require 'path'

module.exports = (env) ->

  class Framework extends require('events').EventEmitter
    configFile: null
    plugins: []
    devices: []
    app: null
    ruleManager: null
    pluginManager: null
    config: null

    constructor: (@configFile) ->
      assert configFile?

      @loadConfig()
      @maindir = path.resolve __dirname, '..'

      @ruleManager = new env.rules.RuleManager this, @config.rules
      @pluginManager = new env.plugins.PluginManager env, this

      @setupExpressApp()

    loadConfig: () ->
      # * Uses `node-convict` for config loading. All config options are in the 
      #   [config-shema](config-shema.html) file.
      conf = convict require("../config-shema")
      
      conf.loadFile @configFile
      # * Performs the validation.
      conf.validate()
      @config = conf.get("")

      # handle legacy config:
      if @config.sensors? and @config.actuators?
        @config.devices = @config.sensors.concat @config.actuators
        delete @config.sensors
        delete @config.actuators
        @saveConfig()

      assert Array.isArray @config.plugins
      assert Array.isArray @config.devices

      # Turn on long Stack traces if debug mode is on.
      Q.longStackSupport = @config.debug

      # * Set the log level
      env.logger.transports.console.level = @config.settings.logLevel

      i18n.configure({
        locales:['en', 'de'],
        directory: __dirname + '/../locales',
        defaultLocale: @config.settings.locale,
      })


    setupExpressApp: () ->
      # Setup express
      # -------------
      @app = express()
      #@app.use express.logger()
      @app.use express.bodyParser()

      # Setup authentication
      # ----------------------
      # Use http-basicAuth if authentication is not disabled.
      auth = @config.settings.authentication
      if auth.enabled
        #Check authentication.
        assert auth.username and typeof auth.username is "string" and auth.username.length isnt 0 
        assert auth.password and typeof auth.password is "string" and auth.password.length isnt 0 
        @app.use express.basicAuth(auth.username, auth.password)

      if not @config.settings.httpsServer?.enabled and 
         not @config.settings.httpServer?.enabled
        env.logger.warn "You have no https and no http server enabled!"

      # Start the https-server if it is enabled.
      if @config.settings.httpsServer?.enabled
        httpsConfig = @config.settings.httpsServer
        assert httpsConfig instanceof Object
        assert typeof httpsConfig.keyFile is 'string' and httpsConfig.keyFile.length isnt 0
        assert typeof httpsConfig.certFile is 'string' and httpsConfig.certFile.length isnt 0 

        httpsOptions = {}
        httpsOptions[name]=value for name, value of httpsConfig
        httpsOptions.key = fs.readFileSync httpsConfig.keyFile
        httpsOptions.cert = fs.readFileSync httpsConfig.certFile
        https = require "https"
        @app.httpsServer = https.createServer httpsOptions, @app

      # Start the http-server if it is enabled.
      if @config.settings.httpServer?.enabled
        http = require "http"
        @app.httpServer = http.createServer @app

    listen: () ->
      genErrFunc = (serverConfig) => 
        return (err) =>
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

      if @app.httpsServer?
        httpsServerConfig = @config.settings.httpsServer
        @app.httpsServer.on 'error', genErrFunc(@config.settings.httpsServer)
        @app.httpsServer.listen httpsServerConfig.port
        env.logger.info "listening for https-request on port #{httpsServerConfig.port}..."

      if @app.httpServer?
        httpServerConfig = @config.settings.httpServer
        @app.httpServer.on 'error', genErrFunc(@config.settings.httpServer)
        @app.httpServer.listen httpServerConfig.port
        env.logger.info "listening for http-request on port #{httpServerConfig.port}..."

      @emit "server listen", "startup"

    loadPlugins: -> 

      checkPluginDependencies = (pConf, plugin) =>
        if plugin.pluginDependencies?
          pluginNames = (p.plugin for p in @config.plugins) 
          for dep in plugin.pluginDependencies
            unless dep in pluginNames
              env.logger.error "Plugin \"#{pConf.plugin}\" depends on \"#{dep}\". " +
                "Please add \"#{dep}\" to your config!"

      # Promise chain, begin with an empty promise
      chain = Q()

      for pConf, i in @config.plugins
        do (pConf, i) =>
          assert pConf?
          assert pConf instanceof Object
          assert pConf.plugin? and typeof pConf.plugin is "string" 

          #legacy support
          if pConf.plugin is "speak-api"
            chain = chain.then =>
              env.logger.info "removing deprecated plugin speak-api!"
              @config.plugins.splice i, 1
            return
          
          chain = chain.then( () =>
            env.logger.info "loading plugin: \"#{pConf.plugin}\"..."
            return @pluginManager.loadPlugin("pimatic-#{pConf.plugin}").then( (plugin) =>
              checkPluginDependencies pConf, plugin
              @registerPlugin(plugin, pConf)
            ).catch( (error) ->
              # If an error occures log an ignore it.
              env.logger.error error.message
              env.logger.debug error.stack
            )
          )

      return chain

    restart: () ->
      unless process.env['PIMATIC_DAEMONIZED']?
        throw new Error 'Can not restart self, when not daemonized. ' +
          'Please run pimatic with: "node ' + process.argv[1] + ' start" to use this feature.'
      # monitor will auto restart script
      process.nextTick -> 
        daemon = require 'daemon'
        env.logger.info("restarting...")
        daemon.daemon process.argv[1], process.argv[2..]
        process.exit 0

    registerPlugin: (plugin, config) ->
      assert plugin? and plugin instanceof env.plugins.Plugin
      assert config? and config instanceof Object

      @plugins.push {plugin: plugin, config: config}
      @emit "plugin", plugin

    getPlugin: (name) ->
      assert name?
      assert typeof name is "string"

      for p in @plugins
        if p.config.plugin is name then return p.plugin
      return null

    registerDevice: (device) ->
      assert device?
      assert device instanceof env.devices.Device
      assert device._constructorCalled
      if @devices[device.id]?
        throw new assert.AssertionError("dublicate device id \"#{device.id}\"")
      unless device.id.match /^[a-z0-9\-_]+$/i
        env.logger.warn """
          The id of #{device.id} contains a non alphanumeric letter or symbol.
          This could lead to errors.
        """
      for reservedWord in ["and", "or", "then"]
        if device.name.indexOf(" and ") isnt -1
          env.logger.warn """
            Name of device "#{device.id}" contains an "#{reservedWord}". 
            This could lead to errors in rules.
          """

      env.logger.info "new device \"#{device.name}\"..."
      @devices[device.id]=device
      @emit "device", device


    loadDevices: ->
      for deviceConfig in @config.devices
        found = false
        for plugin in @plugins
          if plugin.plugin.createDevice?
            found = plugin.plugin.createDevice deviceConfig
            if found then break
        unless found
          env.logger.warn "no plugin found for device \"#{deviceConfig.id}\"!"
      return

    getDeviceById: (id) ->
      @devices[id]

    addDeviceToConfig: (deviceConfig) ->
      assert deviceConfig.id?
      assert deviceConfig.class?

      # Check if device is already in the deviceConfig:
      present = @isDeviceInConfig deviceConfig.id
      if present
        message = "an device with the id #{deviceConfig.id} is already in the config" 
        throw new Error message
      @config.devices.push deviceConfig
      @saveConfig()

    isDeviceInConfig: (id) ->
      assert id?
      for d in @config.devices
        if d.id is id then return true
      return false

    init: ->

      initPlugins = =>
        for plugin in @plugins
          try
            plugin.plugin.init(@app, this, plugin.config)
          catch err
            env.logger.error "Could not initialize the plugin \"#{plugin.config.plugin}\": " +
              err.message
            env.logger.debug err.stack

      initActionHandler = =>
        @ruleManager.addActionHandler new env.actions.SwitchActionHandler env, this
        @ruleManager.addActionHandler new env.actions.LogActionHandler env, this

      initPredicateProvider = =>
        presencePredProvider = new env.predicates.PresencePredicateProvider env, this
        switchPredProvider = new env.predicates.SwitchPredicateProvider env, this
        deviceAttributePredProvider = new env.predicates.DeviceAttributePredicateProvider env, this
        @ruleManager.addPredicateProvider presencePredProvider
        @ruleManager.addPredicateProvider switchPredProvider
        @ruleManager.addPredicateProvider deviceAttributePredProvider
          

      initRules = =>

        addRulePromises = (for rule in @config.rules
          do (rule) =>
            unless rule.active? then rule.active = yes
            @ruleManager.addRuleByString(rule.id, rule.rule, rule.active, true).catch( (err) =>
              env.logger.error "Could not parse rule \"#{rule.rule}\": " + err.message 
              env.logger.debug err.stack
            )        
        )

        return Q.all(addRulePromises).then(=>
          # Save rule updates to the config file:
          # 
          # * If a new rule was added then...
          @ruleManager.on "add", (rule) =>
            # ...add it to the rules Array in the config.json file
            for r in @config.rules 
              if r.id is rule.id then return
            @config.rules.push 
              id: rule.id
              rule: rule.string
              active: rule.active
            @emit "config"
          # * If a rule was changed then...
          @ruleManager.on "update", (rule) =>
            # ...change the rule with the right id in the config.json file
            @config.rules = for r in @config.rules 
              if r.id is rule.id then {id: rule.id, rule: rule.string, active: rule.active}
              else r
            @emit "config"
          # * If a rule was removed then
          @ruleManager.on "remove", (rule) =>
            # ...Remove the rule with the right id in the config.json file
            @config.rules = (r for r in @config.rules when r.id isnt rule.id)
            @emit "config"
        )

      return @loadPlugins()
        .then(initPlugins)
        .then( => @loadDevices())
        .then(initActionHandler)
        .then(initPredicateProvider)
        .then(initRules)
        .then( =>         
          # Save the config on "config" event
          @on "config", =>
            @saveConfig()

          context = 
            waitFor: []
            waitForIt: (promise) -> @waitFor.push promise

          @emit "after init", context

          Q.all(context.waitFor).then => @listen()
        )

    saveConfig: ->
      assert @config?
      try
        fs.writeFileSync @configFile, JSON.stringify(@config, null, 2)
      catch err
        env.logger.error "Could not write config file: ", err.message
        env.logger.debug err
        env.logger.info "config.json updated"