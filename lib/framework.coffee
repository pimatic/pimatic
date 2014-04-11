###
Framework
=========


###
assert = require 'cassert'
fs = require "fs"
convict = require 'convict'
i18n = require 'i18n'
express = require "express"
Q = require 'q'
path = require 'path'
S = require 'string'

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
      @maindir = path.resolve __dirname, '..'
      @pluginManager = new env.plugins.PluginManager(this)
      @packageJson = @pluginManager.getInstalledPackageInfo('pimatic')
      env.logger.info "Starting pimatic version #{@packageJson.version}"
      @loadConfig()
      @variableManager = new env.variables.VariableManager(this, @config.variables)
      @ruleManager = new env.rules.RuleManager(@config.rules)
      @setupExpressApp()

    loadConfig: () ->
      # * Uses `node-convict` for config loading. All config options are in the 
      #   [config-schema](config-schema.html) file.
      conf = convict require("../config-schema")
      
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
      if @config.debug
        Q.longStackSupport = yes
        # require("better-stack-traces").install()

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
      @app.use express.cookieParser()
      @app.use express.urlencoded()
      @app.use express.json()
      auth = @config.settings.authentication
      @app.cookieSessionOptions = {
        secret: "pimatic-#{auth.username}-#{auth.password}"
        key: 'pimatic.sess'
        cookie: { maxAge: null }        
      }
      @app.use express.cookieSession(@app.cookieSessionOptions)
      # Setup authentication
      # ----------------------
      # Use http-basicAuth if authentication is not disabled.
      
      if auth.enabled
        #Check authentication.
        unless auth.username? and typeof auth.username is "string" and auth.username.length isnt 0
          throw new Error(
            "Authentication is enabled, but no username is defined. Please define a " +
            "username in the proper section of the config.json file."
          )

        unless auth.password? and typeof auth.password is "string" and auth.password.length isnt 0
          throw new Error(
            "Authentication is enabled, but no password is defined. Please define a " +
            "password in the proper section of the config.json file or disable authentication."
          )

        
      #req.path
      @app.use (req, res, next) =>
        # set expire date if we should keep loggedin
        if req.query.rememberMe is 'true' then req.session.rememberMe = yes
        if req.query.rememberMe is 'false' then req.session.rememberMe = no

        if req.session.rememberMe and auth.loginTime isnt 0
          req.session.cookie.maxAge = auth.loginTime
        else
          req.session.cookie.maxAge = null
        #touch session to set cookie
        req.session.maxAge = auth.loginTime

        # auth is deactivated so we allways continue
        unless auth.enabled
          req.session.username = ''
          return next()

        # if already logged in so just continue
        if req.session.username is auth.username then return next()
        # not authorized yet

        ###
          if we don't should promp for a password, just fail.
          This does not allow unauthorizied access, it just a workaround to let the browser
          don't show the password prompt on certain ajax requests
        ###
        if req.query.noAuthPromp? then return res.send(401)

        # else use authorization
        express.basicAuth( (user, pass) =>
          valid = (user is auth.username and pass is auth.password)
          # when valid then keep logged in
          if valid then req.session.username = user 
          return valid
        )(req, res, next)

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
        httpsOptions.key = fs.readFileSync path.resolve(@maindir, '../..', httpsConfig.keyFile)
        httpsOptions.cert = fs.readFileSync path.resolve(@maindir, '../..', httpsConfig.certFile)
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
          switch err.code 
            when "EACCES" then msg += "Are you root?."
            when "EADDRINUSE" then msg += "Is a server already running?"
            else msg = null
          if msg?
            env.logger.error msg
            env.logger.debug err.stack
            err.silent = yes  
          throw err

      listenPromises = []
      if @app.httpsServer?
        deferred = Q.defer()
        httpsServerConfig = @config.settings.httpsServer
        @app.httpsServer.on 'error', genErrFunc(@config.settings.httpsServer)
        @app.httpsServer.listen(
          httpsServerConfig.port, httpsServerConfig.hostname, deferred.makeNodeResolver()
        )
        listenPromises.push deferred.promise.then( =>
          env.logger.info "listening for https-request on port #{httpsServerConfig.port}..."
        )
        
      if @app.httpServer?
        deferred = Q.defer()
        httpServerConfig = @config.settings.httpServer
        @app.httpServer.on 'error', genErrFunc(@config.settings.httpServer)
        @app.httpServer.listen(
          httpServerConfig.port, httpServerConfig.hostname, deferred.makeNodeResolver()
        )
        listenPromises.push deferred.promise.then( =>
          env.logger.info "listening for http-request on port #{httpServerConfig.port}..."
        )
        
      Q.all(listenPromises).then( =>
        @emit "server listen", "startup"
      )
      

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
            fullPluginName = "pimatic-#{pConf.plugin}"
            packageInfo = null
            try
              packageInfo = @pluginManager.getInstalledPackageInfo(fullPluginName)
            catch e
              env.logger.debug "Error getting packageinfo of #{fullPluginName}: ", e.message
            env.logger.info("""
              loading plugin: "#{pConf.plugin}" #{
                if packageInfo? then "(" + packageInfo.version  + ")" else ""
              }""")
            return @pluginManager.loadPlugin(fullPluginName).then( (plugin) =>
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

      initVariables = =>
        @variableManager.on("change", (varInfo) =>
          for variable in @config.variables
            if variable.name is varInfo.name
              delete variable.value
              delete variable.expression
              switch varInfo.type
                when 'value' then variable.value = varInfo.value
                when 'expression' then variable.expression = varInfo.exprInputStr
              break
          @emit "config"
        )
        @variableManager.on("add", (varInfo) =>
          switch varInfo.type
            when 'value' then @config.variables.push({
              name: varInfo.name, 
              value: varInfo.value
            })
            when 'expression' then @config.variables.push({
              name: varInfo.name, 
              expression: varInfo.exprInputStr
            })
          @emit "config"
        )
        @variableManager.on("remove", (name) =>
          for variable, i in @config.variables
            if variable.name is name
              @config.variables.splice(i, 1)
              break
          @emit "config"
        )

      initActionProvider = =>
        defaultActionProvider = [
          env.actions.SwitchActionProvider
          env.actions.DimmerActionProvider
          env.actions.LogActionProvider
          env.actions.SetVariableActionProvider
          env.actions.ShutterActionProvider
        ]
        for actProv in defaultActionProvider
          actProvInst = new actProv(this)
          @ruleManager.addActionProvider(actProvInst)

      initPredicateProvider = =>
        defaultPredicateProvider = [
          env.predicates.PresencePredicateProvider
          env.predicates.SwitchPredicateProvider
          env.predicates.DeviceAttributePredicateProvider
          env.predicates.VariablePredicateProvider
          env.predicates.ContactPredicateProvider
        ]
        for predProv in defaultPredicateProvider
          predProvInst = new predProv(this)
          @ruleManager.addPredicateProvider(predProvInst)

      initRules = =>

        addRulePromises = (for rule in @config.rules
          do (rule) =>
            unless rule.active? then rule.active = yes

            unless rule.id.match /^[a-z0-9\-_]+$/i
              newId = S(rule.id).slugify().s
              env.logger.warn """
                The id of the rule "#{rule.id}" contains a non alphanumeric letter or symbol.
                Changing the id of the rule to "#{newId}".
              """
              rule.id = newId

            unless rule.name? then rule.name = S(rule.id).humanize().s

            @ruleManager.addRuleByString(rule.id, rule.name, rule.rule, rule.active, true)
              .catch( (err) =>
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
            @config.rules.push {
              id: rule.id
              name: rule.name
              rule: rule.string
              active: rule.active
            }
            @emit "config"
          # * If a rule was changed then...
          @ruleManager.on "update", (rule) =>
            # ...change the rule with the right id in the config.json file
            @config.rules = for r in @config.rules 
              if r.id is rule.id
                {id: rule.id, name: rule.name, rule: rule.string, active: rule.active}
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
        .then(initVariables)
        .then(initActionProvider)
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
