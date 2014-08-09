###
Framework
=========
###

assert = require 'cassert'
fs = require "fs"
JaySchema = require 'jayschema'
RJSON = require 'relaxed-json'
i18n = require 'i18n'
express = require "express"
socketIo = require 'socket.io'
# Require engine.io from socket.io
engineIo = require.cache[require.resolve('socket.io')].require('engine.io')
Promise = require 'bluebird'
path = require 'path'
S = require 'string'
_ = require 'lodash'
declapi = require 'decl-api'
util = require 'util'
cjson = require 'cjson'

module.exports = (env) ->

  class Framework extends require('events').EventEmitter
    configFile: null
    plugins: []
    devices: {}
    app: null
    io: null
    ruleManager: null
    pluginManager: null
    variableManager: null
    database: null
    config: null
    deviceClasses: {}

    constructor: (@configFile) ->
      assert configFile?
      @maindir = path.resolve __dirname, '..'
      env.logger.winston.on("logged", (level, msg, meta) => 
        @_emitMessageLoggedEvent(level, msg, meta)
      )
      @pluginManager = new env.plugins.PluginManager(this)
      @pluginManager.on('updateProcessStatus', (status, info) =>
        @_emitUpdateProcessStatus(status, info)
      )
      @pluginManager.on('updateProcessMessage', (message, info) =>
        @_emitUpdateProcessMessage(message, info)
      )
      @packageJson = @pluginManager.getInstalledPackageInfo('pimatic')
      env.logger.info "Starting pimatic version #{@packageJson.version}"
      @loadConfig()
      @variableManager = new env.variables.VariableManager(this, @config.variables)
      @ruleManager = new env.rules.RuleManager(this, @config.rules)
      @database = new env.database.Database(this, @config.settings.database)
      @setupExpressApp()

    _validateConfig: (config, schema, scope = "config") ->
      js = new JaySchema()
      errors = js.validate(config, schema)
      if errors.length > 0
        errorMessage = "Invalid #{scope}: "
        for e in errors
          if e.desc?
            errorMessage += e.desc
          else
            errorMessage += (
              "\n#{e.instanceContext}: Should have #{e.constraintName} #{e.constraintValue}"
            )
            if e.testedValue? then errorMessage += ", was: #{e.testedValue}"
        throw new Error(errorMessage)

    loadConfig: () ->
      schema = require("../config-schema")
      contents = fs.readFileSync(@configFile).toString()
      instance = cjson.parse(RJSON.transform(contents))
      @_validateConfig(instance, schema)
      @config = declapi.enhanceJsonSchemaWithDefaults(schema, instance)
      assert Array.isArray @config.plugins
      assert Array.isArray @config.devices
      assert Array.isArray @config.pages
      assert Array.isArray @config.groups

      # * Set the log level
      env.logger.winston.transports.taggedConsoleLogger.level = @config.settings.logLevel

      i18n.configure({
        locales:['en', 'de'],
        directory: __dirname + '/../locales',
        defaultLocale: @config.settings.locale,
      })

    registerDeviceClass: (className, {configDef, createCallback, prepareConfig}) ->
      assert typeof className is "string"
      assert typeof configDef is "object"
      assert typeof createCallback is "function"
      assert(if prepareConfig? then typeof prepareConfig is "function" else true)
      assert typeof configDef.properties is "object"
      configDef.properties.id = {
        description: "the id for the device"
        type: "string"
      }
      configDef.properties.name = {
        description: "the name for the device"
        type: "string"
      }
      configDef.properties.class = {
        description: "the class to use for the device"
        type: "string"
      }

      @deviceClasses[className] = {
        prepareConfig
        configDef
        createCallback
      }

    addPage: (id, page) ->
      if _.findIndex(@config.pages, {id: id}) isnt -1
        throw new Error('A page with this id already exists')
      unless page.name?
        throw new Error('No name given')
      @config.pages.push( page = {
        id: id
        name: page.name
        devices: []
      })
      @saveConfig()
      @_emitPageAdded(page)
      return page

    updatePage: (id, page) ->
      assert typeof id is "string"
      assert typeof page is "object"
      assert(if page.name? then typeof page.name is "string" else true)
      assert(if page.devicesOrder? then Array.isArray page.devicesOrder else true)
      thepage = @getPageById(id)
      unless thepage?
        throw new Error('Page not found')
      thepage.name = page.name if page.name?
      if page.devicesOrder?
        thepage.devices = _.sortBy(thepage.devices,  (device) => 
          index = page.devicesOrder.indexOf device.deviceId
          # push it to the end if not found
          return if index is -1 then 99999 else index 
        )
      @saveConfig()
      @_emitPageChanged(thepage)
      return thepage

    getPageById: (id) -> _.find(@config.pages, {id: id})

    addDeviceToPage: (pageId, deviceId) ->
      page = @getPageById(pageId)
      unless page?
        throw new Error('Could not find the page')
      page.devices.push({
        deviceId: deviceId
      })
      @saveConfig()
      @_emitPageChanged(page)
      return page

    removeDeviceFromPage: (pageId, deviceId) ->
      page = @getPageById(pageId)
      unless page?
        throw new Error('Could not find the page')
      _.remove(page.devices, {deviceId: deviceId})
      @saveConfig()
      @_emitPageChanged(page)
      return page

    removePage: (id, page) ->
      removedPage = _.remove(@config.pages, {id: id})
      @saveConfig() if removedPage.length > 0
      @_emitPageRemoved(removedPage[0])
      return removedPage

    getPages: () ->
      return @config.pages

    addGroup: (id, group) ->
      if _.findIndex(@config.groups, {id: id}) isnt -1
        throw new Error('A group with this id already exists')
      unless group.name?
        throw new Error('No name given')
      @config.groups.push( group = {
        id: id
        name: group.name
        devices: []
        rules: []
        variables: []
      })
      @saveConfig()
      @_emitGroupAdded(group)
      return group

    updateGroup: (id, patch) ->
      index = _.findIndex(@config.groups, {id: id})
      if index is -1
        throw new Error('Group not found')
      group = @config.groups[index]
      
      if patch.name?
        group.name = patch.name 
      if patch.devicesOrder?
        group.devices = _.sortBy(group.devices, (deviceId) => 
          index = patch.devicesOrder.indexOf deviceId 
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      if patch.rulesOrder?
        group.rules = _.sortBy(group.rules, (ruleId) => 
          index = patch.rulesOrder.indexOf ruleId 
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      if patch.variablesOrder
        group.variables = _.sortBy(group.variables, (variableName) => 
          index = patch.variablesOrder.indexOf variableName 
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      @saveConfig()
      @_emitGroupChanged(group)
      return group

    getGroupById: (id) -> _.find(@config.groups, {id: id})

    addDeviceToGroup: (groupId, deviceId, position) ->
      assert(typeof deviceId is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfDevice(deviceId)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.devices, (id) => id is deviceId)
        @_emitGroupChanged(oldGroup)
      unless position? or position >= group.devices.length
        group.devices.push(deviceId)
      else
        group.devices.splice(position, 0, deviceId)
      @saveConfig()
      @_emitGroupChanged(group)
      return group

    getGroupOfRule: (ruleId) ->
      for g in @config.groups
        index = _.indexOf(g.rules, ruleId)
        if index isnt -1 then return g
      return null

    addRuleToGroup: (groupId, ruleId, position) ->
      assert(typeof ruleId is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfRule(ruleId)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.rules, (id) => id is ruleId)
        @_emitGroupChanged(oldGroup)
      unless position? or position >= group.rules.length
        group.rules.push(ruleId)
      else
        group.rules.splice(position, 0, ruleId)
      @saveConfig()
      @_emitGroupChanged(group)
      return group

    getGroupOfVariable: (variableName) ->
      for g in @config.groups
        index = _.indexOf(g.variables, variableName)
        if index isnt -1 then return g
      return null
    
    removeDeviceFromGroup: (groupId, deviceId) ->
      group = @getGroupOfDevice(deviceId)
      unless group?
        throw new Error('Device is in no group')
      if group.id isnt groupId
        throw new Error("Device is not in group #{groupId}")
      _.remove(group.devices, (id) => id is deviceId)
      @saveConfig()
      @_emitGroupChanged(group)      
      return group

    removeRuleFromGroup: (groupId, ruleId) ->
      group = @getGroupOfRule(ruleId)
      unless group?
        throw new Error('Rule is in no group')
      if group.id isnt groupId
        throw new Error("Rule is not in group #{groupId}")
      _.remove(group.rules, (id) => id is ruleId)
      @saveConfig()
      @_emitGroupChanged(group)      
      return group

    removeVariableFromGroup: (groupId, variableName) ->
      group = @getGroupOfVariable(variableName)
      unless group?
        throw new Error('Variable is in no group')
      if group.id isnt groupId
        throw new Error("Variable is not in group #{groupId}")
      _.remove(group.variables, (name) => name is variableName)
      @saveConfig()
      @_emitGroupChanged(group)      
      return group

    addVariableToGroup: (groupId, variableName, position) ->
      assert(typeof variableName is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfVariable(variableName)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.variables, (name) => name is variableName)
        @_emitGroupChanged(oldGroup)
      unless position? or position >= group.variables.length
        group.variables.push(variableName)
      else
        group.variables.splice(position, 0, variableName)
      @saveConfig()
      @_emitGroupChanged(group)
      return group

    removeGroup: (id, page) ->
      removedGroup = _.remove(@config.groups, {id: id})
      @saveConfig() if removedGroup.length > 0
      @_emitGroupRemoved(removedGroup[0])
      return removedGroup

    getGroupOfDevice: (deviceId) ->
      for g in @config.groups
        index = _.indexOf(g.devices, deviceId)
        if index isnt -1 then return g
      return null

    getGroups: () ->
      return @config.groups

    updateRuleOrder: (ruleOrder) ->
      assert ruleOrder? and Array.isArray ruleOrder
      @config.rules = _.sortBy(@config.rules,  (rule) => 
        index = ruleOrder.indexOf rule.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @saveConfig()
      @_emitRuleOrderChanged(ruleOrder)
      return ruleOrder

    updateDeviceOrder: (deviceOrder) ->
      assert deviceOrder? and Array.isArray deviceOrder
      @config.devices = _.sortBy(@config.devices,  (device) => 
        index = deviceOrder.indexOf device.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @saveConfig()
      @_emitDeviceOrderChanged(deviceOrder)
      return deviceOrder

    updateVariableOrder: (variableOrder) ->
      assert variableOrder? and Array.isArray variableOrder
      @config.variables = _.sortBy(@config.variables,  (variable) => 
        index = variableOrder.indexOf variable.name
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @saveConfig()
      @_emitVariableOrderChanged(variableOrder)
      return variableOrder

    updateGroupOrder: (groupOrder) ->
      assert groupOrder? and Array.isArray groupOrder
      @config.groups = _.sortBy(@config.groups,  (group) => 
        index = groupOrder.indexOf group.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @saveConfig()
      @_emitGroupOrderChanged(groupOrder)
      return groupOrder

    updatePageOrder: (pageOrder) ->
      assert pageOrder? and Array.isArray pageOrder
      @config.pages = _.sortBy(@config.pages,  (page) => 
        index = pageOrder.indexOf page.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @saveConfig()
      @_emitPageOrderChanged(pageOrder)
      return pageOrder

    setupExpressApp: () ->
      # Setup express
      # -------------
      @app = express()
      #@app.use express.logger()
      @app.use express.cookieParser()
      @app.use express.urlencoded(limit: '10mb')
      @app.use express.json(limit: '10mb')
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
      
      assert auth.enabled in [yes, no]

      if auth.enabled is yes
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
      @app.use( (req, res, next) =>
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
        if auth.enabled is no
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
      )

      @app.get('/remember', (req, res) =>
        rememberMe = req.query.rememberMe
        # rememberMe is handled by the framework, so see if it was picked up:
        if rememberMe is 'true' then rememberMe = yes
        if rememberMe is 'false' then rememberMe = no
        if req.session.rememberMe is rememberMe
          res.send 200, { success: true,  message: 'done' }
        else 
          res.send 200, {success: false, message: 'illegal param'}
        return
      )

      serverEnabled = (
        @config.settings.httpsServer?.enabled or @config.settings.httpServer?.enabled
      )

      unless serverEnabled 
        env.logger.warn "You have no https and no http server enabled!"

      @initRestApi()

      socketIoPath = '/socket.io'
      engine = new engineIo.Server({path: socketIoPath})
      @io = new socketIo()
      ioCookieParser = express.cookieParser(@app.cookieSessionOptions.secret)
      @io.use( (socket, next) =>
        if auth.enabled is no
          return next()
        req = socket.request 
        if req.headers.cookie?
          req.cookies = null
          ioCookieParser(req, null, =>
            sessionCookie = req.signedCookies?[@app.cookieSessionOptions.key]
            if sessionCookie? and sessionCookie.username is auth.username
              return next()
            else 
              env.logger.debug "socket.io: Cookie is invalid."
              return next(new Error('Authentication error'))
          )
        else
          env.logger.warn "No cookie transmitted."
          return next(new Error('unauthorizied'))
      )

      @io.bind(engine)

      @app.all( '/socket.io/socket.io.js', (req, res) => @io.serve(req, res) )
      @app.all( '/socket.io/*', (req, res) => engine.handleRequest(req, res) )

      onUpgrade = (req, socket, head) =>
        if socketIoPath is req.url.substr(0, socketIoPath.length)
          engine.handleUpgrade(req, socket, head)
        else
          socket.end()
        return

      # Start the https-server if it is enabled.
      if @config.settings.httpsServer?.enabled
        httpsConfig = @config.settings.httpsServer
        assert httpsConfig instanceof Object
        assert typeof httpsConfig.keyFile is 'string' and httpsConfig.keyFile.length isnt 0
        assert typeof httpsConfig.certFile is 'string' and httpsConfig.certFile.length isnt 0 

        httpsOptions = {}
        httpsOptions[name] = value for name, value of httpsConfig
        httpsOptions.key = fs.readFileSync path.resolve(@maindir, '../..', httpsConfig.keyFile)
        httpsOptions.cert = fs.readFileSync path.resolve(@maindir, '../..', httpsConfig.certFile)
        https = require "https"
        @app.httpsServer = https.createServer httpsOptions, @app
        @app.httpsServer.on('upgrade', onUpgrade)

      # Start the http-server if it is enabled.
      if @config.settings.httpServer?.enabled
        http = require "http"
        @app.httpServer = http.createServer @app
        @app.httpServer.on('upgrade', onUpgrade)

      actionsWithBindings = [
        [env.api.framework.actions, this]
        [env.api.rules.actions, @ruleManager]
        [env.api.variables.actions, @variableManager]
        [env.api.plugins.actions, @pluginManager]
        [env.api.database.actions, @database]
      ]

      onError = (error) =>
        env.logger.error(error.message)
        env.logger.debug(error)

      @io.on('connection', (socket) =>
        declapi.createSocketIoApi(socket, actionsWithBindings, onError)
        socket.emit('devices', (d.toJson() for d in @getDevices()) )
        socket.emit('rules', (r.toJson() for r in @ruleManager.getRules()) )
        socket.emit('variables', (v.toJson() for v in @variableManager.getVariables()) )
        socket.emit('pages',  @getPages() )
        socket.emit('groups',  @getGroups() )
      )

    listen: () ->
      genErrFunc = (serverConfig) => 
        return (err) =>
          msg = "Could not listen on port #{serverConfig.port}. Error: #{err.message}. "
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
        httpsServerConfig = @config.settings.httpsServer
        @app.httpsServer.on 'error', genErrFunc(@config.settings.httpsServer)
        awaiting = Promise.promisify(@app.httpsServer.listen, @app.httpsServer)(
          httpsServerConfig.port, httpsServerConfig.hostname
        )
        listenPromises.push awaiting.then( =>
          env.logger.info "listening for https-request on port #{httpsServerConfig.port}..."
        )
        
      if @app.httpServer?
        httpServerConfig = @config.settings.httpServer
        @app.httpServer.on 'error', genErrFunc(@config.settings.httpServer)
        awaiting = Promise.promisify(@app.httpServer.listen, @app.httpServer)(
          httpServerConfig.port, httpServerConfig.hostname
        )
        listenPromises.push awaiting.then( =>
          env.logger.info "listening for http-request on port #{httpServerConfig.port}..."
        )
        
      Promise.all(listenPromises).then( =>
        @emit "server listen", "startup"
      )
      

    loadPlugins: -> 

      checkPluginDependencies = (pConf, plugin) =>
        if plugin.pluginDependencies?
          pluginNames = (p.plugin for p in @config.plugins) 
          for dep in plugin.pluginDependencies
            unless dep in pluginNames
              env.logger.error(
                "Plugin \"#{pConf.plugin}\" depends on \"#{dep}\". " +
                "Please add \"#{dep}\" to your config!"
              )

      # Promise chain, begin with an empty promise
      chain = Promise.resolve()

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
            Promise.try( =>     
              # If the plugin folder already exist
              return promise = (
                if @pluginManager.isInstalled(fullPluginName) then Promise.resolve()
                else 
                  env.logger.info("Installing: \"#{pConf.plugin}\"")
                  @pluginManager.installPlugin(fullPluginName)
              )
            ).then( =>
              return @pluginManager.loadPlugin(fullPluginName).then( ([plugin, packageInfo]) =>
                checkPluginDependencies(pConf, plugin)
                # Check config
                if packageInfo.configSchema?
                  pathToSchema = path.resolve(
                    @pluginManager.pathToPlugin(fullPluginName), 
                    packageInfo.configSchema
                  )
                  configSchema = require(pathToSchema)
                  @_validateConfig(pConf, configSchema, "config of #{fullPluginName}")
                  pConf = declapi.enhanceJsonSchemaWithDefaults(configSchema, pConf)
                else
                  env.logger.warn(
                    "package.json of \"#{fullPluginName}\" has no \"configSchema\" property. " +
                    "Could not validate config."
                  )
                @registerPlugin(plugin, pConf, configSchema)
              ).catch( (error) ->
                # If an error occures log an ignore it.
                env.logger.error error.message
                env.logger.debug error.stack
              )
            )
          )

      return chain

    restart: () ->
      unless process.env['PIMATIC_DAEMONIZED']?
        throw new Error(
          'Can not restart self, when not daemonized. ' +
          'Please run pimatic with: "node ' + process.argv[1] + ' start" to use this feature.'
        )
      # monitor will auto restart script
      process.nextTick -> 
        daemon = require 'daemon'
        env.logger.info("restarting...")
        daemon.daemon process.argv[1], process.argv[2..]
        process.exit 0

    registerPlugin: (plugin, config, packageInfo) ->
      assert plugin? and plugin instanceof env.plugins.Plugin
      assert config? and config instanceof Object

      @plugins.push {plugin, config, packageInfo}
      @emit "plugin", plugin

    getPlugin: (name) ->
      assert name?
      assert typeof name is "string"

      for p in @plugins
        if p.config.plugin is name then return p.plugin
      return null

    addPluginsToConfig: (plugins) ->
      Array.isArray pluginNames
      pluginNames = (p.plugin for p in @config.plugins)
      added = []
      for p in plugins
        unless p in pluginNames
          @config.plugins.push {plugin: p}
          added.push p
      @saveConfig()
      return added

    removePluginsFromConfig: (plugins) ->
      removed = _.remove(@config.plugins, (p) -> p.plugin in plugins)
      @saveConfig()
      return removed

    getGuiSetttings: () -> {
      config: @config.settings.gui
      defaults: @config.settings.gui.__proto__
    }

    _emitDeviceAttributeEvent: (device, attributeName, attribute, time, value) ->
      @emit 'deviceAttributeChanged', {device, attributeName, attribute, time, value}
      @io?.emit 'deviceAttributeChanged', {deviceId: device.id, attributeName, time, value}


    _emitDeviceEvent: (eventType, device) ->
      @emit(eventType, device)
      @io?.emit(eventType, device.toJson())

    _emitDeviceAdded: (device) -> @_emitDeviceEvent('deviceAdded', device)
    _emitDeviceChanged: (device) -> @_emitDeviceEvent('deviceChanged', device)
    _emitDeviceRemoved: (device) -> @_emitDeviceEvent('deviceRemoved', device)

    _emitDeviceOrderChanged: (deviceOrder) ->
      @_emitOrderChanged('deviceOrderChanged', deviceOrder)

    _emitMessageLoggedEvent: (level, msg, meta) ->
      @emit 'messageLogged', {level, msg, meta}
      @io?.emit 'messageLogged', {level, msg, meta}

    _emitOrderChanged: (eventName, order) ->
      @emit(eventName, order)
      @io?.emit(eventName, order)

    _emitPageEvent: (eventType, page) ->
      @emit(eventType, page)
      @io?.emit(eventType, page)

    _emitPageAdded: (page) -> @_emitPageEvent('pageAdded', page)
    _emitPageChanged: (page) -> @_emitPageEvent('pageChanged', page)
    _emitPageRemoved: (page) -> @_emitPageEvent('pageRemoved', page)
    _emitPageOrderChanged: (pageOrder) ->
      @_emitOrderChanged('pageOrderChanged', pageOrder)

    _emitGroupEvent: (eventType, group) ->
      @emit(eventType, group)
      @io?.emit(eventType, group)

    _emitGroupAdded: (group) -> @_emitGroupEvent('groupAdded', group)
    _emitGroupChanged: (group) -> @_emitGroupEvent('groupChanged', group)
    _emitGroupRemoved: (group) -> @_emitGroupEvent('groupRemoved', group)
    _emitGroupOrderChanged: (proupOrder) ->
      @_emitOrderChanged('groupOrderChanged', proupOrder)

    _emitRuleEvent: (eventType, rule) ->
      @emit(eventType, rule)
      @io?.emit(eventType, rule.toJson())

    _emitRuleAdded: (rule) -> @_emitRuleEvent('ruleAdded', rule)
    _emitRuleRemoved: (rule) -> @_emitRuleEvent('ruleRemoved', rule)
    _emitRuleChanged: (rule) -> @_emitRuleEvent('ruleChanged', rule)
    _emitRuleOrderChanged: (ruleOrder) ->
      @_emitOrderChanged('ruleOrderChanged', ruleOrder)

    _emitVariableEvent: (eventType, variable) ->
      @emit(eventType, variable)
      @io?.emit(eventType, variable.toJson())

    _emitVariableAdded: (variable) -> @_emitVariableEvent('variableAdded', variable)
    _emitVariableRemoved: (variable) -> @_emitVariableEvent('variableRemoved', variable)
    _emitVariableChanged: (variable) -> @_emitVariableEvent('variableChanged', variable)
    _emitVariableValueChanged: (variable, value) ->
      @emit("variableValueChanged", variable, value)
      @io?.emit("variableValueChanged", {
        variableName: variable.name
        variableValue: value
      })

    _emitVariableOrderChanged: (variableOrder) ->
      @_emitOrderChanged('variableOrderChanged', variableOrder)

    _emitUpdateProcessStatus: (status, info) ->
      @emit 'updateProcessStatus', status, info
      @io?.emit("updateProcessStatus", {
        status: status
        modules: info.modules
      }) 

    _emitUpdateProcessMessage: (message, info) ->
      @emit 'updateProcessMessages', message, info
      @io?.emit("updateProcessMessages", {
        message: message
        modules: info.modules
      }) 
      
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

      for attrName, attr of device.attributes
        do (attrName, attr) =>
          device.on(attrName, onChange = (value) => 
            @_emitDeviceAttributeEvent(device, attrName, attr,  new Date(), value)
          )
      device.afterRegister()
      @_emitDeviceAdded(device)
      return device

    _loadDevice: (deviceConfig) ->
      classInfo = @deviceClasses[deviceConfig.class]
      unless classInfo?
        throw new Error("Unknown device class \"#{deviceConfig.class}\"")
      warnings = []
      classInfo.prepareConfig(deviceConfig) if classInfo.prepareConfig?
      @_validateConfig(deviceConfig, classInfo.configDef, "config of device #{deviceConfig.id}")
      declapi.checkConfig(classInfo.configDef.properties, deviceConfig, warnings)
      for w in warnings
        env.logger.warn("Device configuration of #{deviceConfig.id}: #{w}")
      deviceConfig = declapi.enhanceJsonSchemaWithDefaults(classInfo.configDef, deviceConfig)
      device = classInfo.createCallback(deviceConfig)
      assert deviceConfig is device.config
      return @registerDevice(device)


    loadDevices: ->
      for deviceConfig in @config.devices
        classInfo = @deviceClasses[deviceConfig.class]
        if classInfo?
          try
            @_loadDevice(deviceConfig)
          catch e
            env.logger.error("Error loading device #{deviceConfig.id}: #{e.message}")
            env.logger.debug(e)
        else
          env.logger.warn(
            "no plugin found for device \"#{deviceConfig.id}\" of class \"#{deviceConfig.class}\"!"
          )
      return

    getDeviceById: (id) -> @devices[id]

    getDevices: -> (device for id, device of @devices)

    getDeviceClasses: -> (className for className of @deviceClasses)

    getDeviceConfigSchema: (className)-> @deviceClasses[className]?.configDef

    addDeviceByConfig: (deviceConfig) ->
      assert deviceConfig.id?
      assert deviceConfig.class?
      if @isDeviceInConfig(deviceConfig.id)
        throw new Error(
          "A device with the id \"#{deviceConfig.id}\" is already in the config."
        )
      device = @_loadDevice(deviceConfig)
      @addDeviceToConfig(deviceConfig)
      return device

    updateDeviceByConfig: (deviceConfig) ->
      throw new Error("The Operation isn't supported yet.")

    removeDevice: (deviceId) ->
      device = @getDeviceById(deviceId)
      unless device? then return
      @_emitDeviceRemoved(device)
      device.emit 'remove'
      @config.devices = (d for d in @config.devices when d.id isnt deviceId)
      @saveConfig()
      device.destroy()
      return device


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
            env.logger.error(
              "Could not initialize the plugin \"#{plugin.config.plugin}\": " +
              err.message
            )
            env.logger.debug err.stack

      initVariables = =>
        @variableManager.init()
        @variableManager.on("variableChanged", (changedVar) =>
          for variable in @config.variables
            if variable.name is changedVar.name
              delete variable.value
              delete variable.expression
              switch changedVar.type
                when 'value' then variable.value = changedVar.value
                when 'expression' then variable.expression = changedVar.exprInputStr
              break
          @_emitVariableChanged(changedVar)
          @emit "config"
        )
        @variableManager.on("variableValueChanged", (changedVar, value) =>
          if changedVar.type is 'value'
            for variable in @config.variables
              if variable.name is changedVar.name
                variable.value = value
                break
            @emit "config"
          @_emitVariableValueChanged(changedVar, value)
          
        )
        @variableManager.on("variableAdded", (addedVar) =>
          switch addedVar.type
            when 'value' then @config.variables.push({
              name: addedVar.name, 
              value: addedVar.value
            })
            when 'expression' then @config.variables.push({
              name: addedVar.name, 
              expression: addedVar.exprInputStr
            })
          @_emitVariableAdded(addedVar)
          @emit "config"
        )
        @variableManager.on("variableRemoved", (removedVar) =>
          for variable, i in @config.variables
            if variable.name is removedVar.name
              @config.variables.splice(i, 1)
              break
          @_emitVariableRemoved(removedVar)
          @emit "config"
        )

      initActionProvider = =>
        defaultActionProvider = [
          env.actions.SwitchActionProvider
          env.actions.DimmerActionProvider
          env.actions.LogActionProvider
          env.actions.SetVariableActionProvider
          env.actions.ShutterActionProvider
          env.actions.StopShutterActionProvider
          env.actions.ToggleActionProvider
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
          env.predicates.ButtonPredicateProvider
          env.predicates.DeviceAttributeWatchdogProvider
        ]
        for predProv in defaultPredicateProvider
          predProvInst = new predProv(this)
          @ruleManager.addPredicateProvider(predProvInst)

      initDevices = =>
        deviceConfigDef = require("../device-config-schema")
        defaultDevices = [
          env.devices.ButtonsDevice
          env.devices.VariablesDevice
        ]
        for deviceClass in defaultDevices
          do (deviceClass) =>
            @registerDeviceClass(deviceClass.name, {
              configDef: deviceConfigDef[deviceClass.name], 
              createCallback: (config) => 
                return new deviceClass(config, this)
            })

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

            @ruleManager.addRuleByString(rule.id, {
              name: rule.name, 
              ruleString: rule.rule, 
              active: rule.active
            }, force = true).catch( (err) =>
              env.logger.error "Could not parse rule \"#{rule.rule}\": " + err.message 
              env.logger.debug err.stack
            )        
        )

        return Promise.all(addRulePromises).then(=>
          # Save rule updates to the config file:
          # 
          # * If a new rule was added then...
          @ruleManager.on "ruleAdded", (rule) =>
            # ...add it to the rules Array in the config.json file
            inConfig = (_.findIndex(@config.rules , {id: rule.id}) isnt -1)
            unless inConfig
              @config.rules.push {
                id: rule.id
                name: rule.name
                rule: rule.string
                active: rule.active
                logging: rule.logging
              }
            @_emitRuleAdded(rule)
            @emit "config"
          # * If a rule was changed then...
          @ruleManager.on "ruleChanged", (rule) =>
            # ...change the rule with the right id in the config.json file
            @config.rules = for r in @config.rules 
              if r.id is rule.id
                {
                  id: rule.id, 
                  name: rule.name,
                  rule: rule.string,
                  active: rule.active,
                  logging: rule.logging
                }
              else r
            @_emitRuleChanged(rule)
            @emit "config"
          # * If a rule was removed then
          @ruleManager.on "ruleRemoved", (rule) =>
            # ...Remove the rule with the right id in the config.json file
            @config.rules = (r for r in @config.rules when r.id isnt rule.id)
            @_emitRuleRemoved(rule)
            @emit "config"
        )

      return @database.init()
        .then( => @loadPlugins())
        .then(initPlugins)
        .then(initDevices)
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

          Promise.all(context.waitFor).then => @listen()
        )

    initRestApi: ->
      onError = (error) =>
        if error instanceof Error
          message = error.message
          env.logger.error error.message
          env.logger.debug error.stack

      @app.get("/api/device/:deviceId/:actionName", (req, res, next) =>
        deviceId = req.params.deviceId
        actionName = req.params.actionName
        device = @getDeviceById(deviceId)
        if device?
          if device.hasAction(actionName)
            action = device.actions[actionName]
            declapi.callActionFromReqAndRespond(actionName, action, device, req, res)
          else
            declapi.sendErrorResponse(res, 'device hasn\'t that action')
        else declapi.sendErrorResponse(res, 'device not found')
      )

      @app.get("/api", (req, res, nest) => res.send(declapi.stringifyApi(env.api.all)) )
      @app.get("/api/decl-api-client.js", declapi.serveClient)

      declapi.createExpressRestApi(@app, env.api.framework.actions, this, onError)
      declapi.createExpressRestApi(@app, env.api.rules.actions, this.ruleManager, onError)
      declapi.createExpressRestApi(@app, env.api.variables.actions, this.variableManager, onError)
      declapi.createExpressRestApi(@app, env.api.plugins.actions, this.pluginManager, onError)
      declapi.createExpressRestApi(@app, env.api.database.actions, this.database, onError)

    saveConfig: ->
      assert @config?
      try
        fs.writeFileSync @configFile, JSON.stringify(@config, null, 2)
      catch err
        env.logger.error "Could not write config file: ", err.message
        env.logger.debug err
        env.logger.info "config.json updated"

  return { Framework }
