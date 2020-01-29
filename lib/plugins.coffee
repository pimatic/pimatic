
###
Plugin Manager
=======
###

Promise = require 'bluebird'
fs = require 'fs.extra'; Promise.promisifyAll(fs)
path = require 'path'
util = require 'util'
assert = require 'cassert'
byline = require 'byline'
_ = require 'lodash'
spawn = require("cross-spawn")
https = require "https"
semver = require "semver"
events = require 'events'
S = require 'string'
declapi = require 'decl-api'
rp = require 'request-promise'
download = require 'gethub'
blacklist = require '../blacklist.json'

module.exports = (env) ->

  isCompatible = (refVersion, packageInfo) ->
    try
      peerVersion = packageInfo.peerDependencies?.pimatic
      if peerVersion?
        if semver.satisfies(refVersion, peerVersion)
          return true
    catch err
      env.logger.error(err)
    return false

  satisfyingVersion = (p, refVersion) ->
    versions = []
    _.forEach(p.versions, (value, key) =>
      if isCompatible(refVersion, value)
        versions.push key
    )
    
    return versions

  getLatestCompatible = (packageInfo, refVersion) ->
    result = packageInfo.versions[packageInfo['dist-tags'].latest]
    if isCompatible(refVersion, result)
      return result
    else
      satisfyingV = satisfyingVersion(packageInfo, refVersion)
      if satisfyingV.length > 0
        latestSatisfying = satisfyingV[satisfyingV.length-1]
        result = packageInfo.versions[latestSatisfying]
        return result
      else
        # no compatible version found, return latest
        return result
    return result

  class PluginManager extends events.EventEmitter
    plugins: []
    updateProcessStatus: 'idle'
    updateProcessMessages: []
    restartRequired: false

    constructor: (@framework) ->
      @modulesParentDir = path.resolve @framework.maindir, '../../'

    checkNpmVersion: () ->
      @spawnPpm(['--version']).catch( (err) =>
        env.logger.error("Could not run ppm, plugin and module installation will not work.")
      )

    # Loads the given plugin by name
    loadPlugin: (name, config) ->
      packageInfo = @getInstalledPackageInfo(name)
      packageInfoStr = (if packageInfo? then "(" + packageInfo.version  + ")" else "")
      env.logger.info("""Loading plugin: "#{name}" #{packageInfoStr}""")
      # require the plugin and return it
      # create a sublogger:
      pluginEnv = Object.create(env)
      pluginEnv.logger = env.logger.base.createSublogger(name, config.debug)
      if config.debug
        env.logger.debug("debug is true in plugin config, showing debug output for #{name}.")
      plugin = (require name) pluginEnv, module
      return Promise.resolve([plugin, packageInfo])

    # Checks if the plugin folder exists under node_modules
    isInstalled: (name) ->
      assert name?
      assert name.match(/^pimatic.*$/)?
      return fs.existsSync(@pathToPlugin name)

    isGitRepo: (name) ->
      assert name?
      assert name.match(/^pimatic.*$/)?
      return fs.existsSync("#{@pathToPlugin name}/.git")

    _getFullPlatfrom: ->
      abiVersion = process.versions.modules
      platform = process.platform
      arch = if process.arch is "arm" then "armhf" else process.arch
      return "node-#{abiVersion}-#{arch}-#{platform}"

    _findDist: (plugin) ->
      if (not plugin.dists?) or plugin.dists.length is 0 then return null
      fullPlatform = @_getFullPlatfrom()
      for dist in plugin.dists
        if dist.name.indexOf(fullPlatform) is 0
          return dist
      return null

    # Install a plugin from the npm repository
    installPlugin: (name, update = false) ->
      assert name?
      assert name.match(/^pimatic.*$/)?
      if update
        if @isGitRepo(name) then throw new Error("Can't update a git repository!")
      return @getPluginInfo(name).then( (packageInfo) =>
        unless packageInfo?
          env.logger.warn(
            "Could not determine compatible version for \"#{name}\"" +
            ", trying to installing latest version"
          )
          env.logger.info("Installing: \"#{name}\" from npm-registry.")
          if update
            return @spawnPpm(['update', name, '--unsafe-perm'])
          else
            return @spawnPpm(['install', name, '--unsafe-perm'])
        dist = @_findDist(packageInfo)
        if dist
          return if update then @updateGitPlugin(name) else @installGitPlugin(name)
        plugin = "#{packageInfo.name}@#{packageInfo.version}"
        env.logger.info("Installing: \"#{plugin}\" from npm-registry.")
        return @spawnPpm(['install', "#{plugin}", '--unsafe-perm'])
      )

    updatePlugin: (name) ->
      return @installPlugin(name, true)

    uninstallPlugin: (name) ->
      pluginDir = @pathToPlugin(name)
      @requrieRestart()
      return fs.rmrfAsync(pluginDir)

    _emitUpdateProcessStatus: (status, info) ->
      @updateProcessStatus = status
      @emit 'updateProcessStatus', status, info

    _emitUpdateProcessMessage: (message, info) ->
      @updateProcessMessages.push message
      @emit 'updateProcessMessage', message, info

    getUpdateProcessStatus: () ->
      return {
        status: @updateProcessStatus
        messages: @updateProcessMessages
      }

    install: (modules) ->
      info = {modules}
      @_emitUpdateProcessStatus('running', info)
      npmMessageListener = ( (line) => @_emitUpdateProcessMessage(line, info) )
      @on 'npmMessage', npmMessageListener
      hasErrors = false
      return Promise.each(modules, (plugin) =>
        (if @isInstalled(plugin) then @updatePlugin(plugin) else @installPlugin(plugin))
        .catch( (error) =>
          env.logger.error("Error installing plugin #{plugin}: #{error.message}")
          env.logger.debug(error.stack)
        )
      ).then( =>
        @_emitUpdateProcessStatus('done', info)
        @requrieRestart()
        @removeListener 'npmMessage', npmMessageListener
        return modules
      ).catch( (error) =>
        @_emitUpdateProcessStatus('error', info)
        @removeListener 'npmMessage', npmMessageListener
        throw error
      )

    pathToPlugin: (name) ->
      assert name?
      assert name.match(/^pimatic.*$/)? or name is "pimatic"
      pluginName = @extractPluginName(name)
      return path.resolve @framework.maindir, "..", pluginName

    getPluginList: ->
      if @_pluginList then return @_pluginList
      else return @searchForPlugin()

    getCoreInfo: ->
      if @_coreInfo then return @_coreInfo
      else return @searchForCoreUpdate()

    extractPluginName: (name) ->
      versionInfo = @getSpecificVersionInfo(name)
      return if versionInfo? then versionInfo.name else name

    getSpecificVersionInfo: (name) ->
      if match = /^(pimatic.*)@(.*)$/.exec(name)
        return {
          name: match[1]
          version: match[2]
        }

    _tranformRequestErrors: (err) ->
      if err.name is 'RequestError'
        throw new Error(
          """
          Could not connect to the pimatic update server: #{err.message}
          Either the update server is currently not available or your internet connection is down.
          """)
      throw err


    searchForPlugin: ->
      version = @framework.packageJson.version
      return @_pluginList = rp("http://api.pimatic.org/plugins?version=#{version}")
        .catch(@_tranformRequestErrors)
        .then( (res) =>
          json = JSON.parse(res)
          if json.error?
            throw new Error ("#{json.error}: #{version}")
          
          for name in blacklist
            json = json.filter (item) -> item.name isnt name
          
          # Filter packages based on Node compatibility
          json = json.filter (p) => @isNodeVersionCompatible(p.engines?.node)
          
          # sort
          json.sort( (a, b) => a.name.localeCompare(b.name) )
          # cache for 1min
          setTimeout( (=> @_pluginList = null), 60*1000)
          return json
        ).catch( (err) =>
          # cache errors only for 1 sec
          setTimeout( (=> @_pluginList = null), 1*1000)
          throw err
        )

    searchForCoreUpdate: ->
      version = @framework.packageJson.version
      return @_coreInfo = rp("http://api.pimatic.org/core?version=#{version}")
        .catch(@_tranformRequestErrors)
        .then( (res) =>
          json = JSON.parse(res)
          # cache for 1min
          setTimeout( (=> @_coreInfo = null), 60*1000)
          return json
        ).catch( (err) =>
          # cache errors only for 1 sec
          setTimeout( (=> @_coreInfo = null), 1*1000)
          throw err
        )

    getPluginInfo: (name) ->
      return @getCoreInfo() if name is "pimatic"
      return Promise.resolve(@getSpecificVersionInfo(name)) if name.match(/^pimatic.*@.*$/)
      pluginInfo = null
      return @getPluginList().then( (plugins) =>
        pluginInfo = _.find(plugins, (p) -> p.name is name)
      ).finally( () =>
        unless pluginInfo?
          env.logger.info("Could not get plugin info from update server, request info from npm")
          return pluginInfo = @getPluginInfoFromNpm(name)
      ).then( () =>  
        return pluginInfo
      )

    getPluginInfoFromNpm: (name) ->
      return rp("https://registry.npmjs.org/#{name}").then( (res) =>
        packageInfos = JSON.parse(res)
        if packageInfos.error?
          throw new Error(
            "Error getting info about #{name} from npm failed: #{packageInfos.reason}")
        return getLatestCompatible(packageInfos, @framework.packageJson.version)
      )

    isCompatible: (packageInfo) ->
      version = @framework.packageJson.version
      pimaticRange = packageInfo.peerDependencies?.pimatic
      unless pimaticRange
        return null
      return semver.satisfies(version, pimaticRange)
    
    isNodeVersionCompatible: (version) ->
      # No node attribute in package for downward compat purposes
      # as not all maintainers have included { engines: { node: "x.x.x" }} in package.json
      !version || semver.satisfies(@getInstalledNodeVersion(), version)
    
    getInstalledNodeVersion: () ->
      return "#{process.versions.node}"
    
    searchForPluginsWithInfo: ->
      return @searchForPlugin().then( (plugins) =>
        return pluginList = (
          for p in plugins
            name = p.name.replace 'pimatic-', ''
            loadedPlugin = @framework.pluginManager.getPlugin name
            installed = @isInstalled p.name
            packageJson = (
              if installed then @getInstalledPackageInfo p.name
              else null
            )
            listEntry = {
              name: name
              description: p.description
              version: p.version
              installed: installed
              loaded: loadedPlugin?
              activated: @isActivated(name)
              isNewer: (if installed then semver.gt(p.version, packageJson.version) else false)
              isCompatible: @isCompatible(p)
            }
        )
      )

    isPimaticOutdated: ->
      installed = @getInstalledPackageInfo("pimatic")
      return @getPluginInfo("pimatic").then( (latest) =>
        if semver.gt(latest.version, installed.version)
          return {
            current: installed.version
            latest: latest.version
          }
        else return false
      )

    getOutdatedPlugins: ->
      return @getInstalledPluginUpdateVersions().then( (result) =>
        outdated = []
        for p in result
          if semver.gt(p.latest, p.current) and @isNodeVersionCompatible(p.node)
            outdated.push p
        return outdated
      )

    getInstalledPluginUpdateVersions: ->
      return @getInstalledPlugins().then( (plugins) =>
        waiting = []
        infos = []
        for p in plugins
          do (p) =>
            installed = @getInstalledPackageInfo(p)
            waiting.push @getPluginInfo(p).then( (latest) =>
              infos.push {
                plugin: p
                current: installed.version
                latest: latest.version
                node: latest.engines?.node # Add node engine from updated package to check later
              }
            )
        return Promise.settle(waiting).then( (results) =>
          env.logger.error(r.reason()) for r in results when r.isRejected()

          ret = []
          for info in infos
            unless info.current?
              env.logger.warn "Could not get the installed package version of #{info.plugin}"
              continue
            unless info.latest?
              env.logger.warn "Could not get the latest version of #{info.plugin}"
              continue
            ret.push info
          return ret
        )
      )

    spawnPpm: (args) ->
      return new Promise( (resolve, reject) =>
        if @npmRunning
          reject "npm is currently in use"
          return
        @npmRunning = yes
        output = ''
        npmLogger = env.logger.createSublogger("ppm")
        errCode = null
        errorMessage = null
        onLine = ( (line) =>
          line = line.toString()
          if (match = line.match(/ERR! code (E[A-Z]+)/))?
            errCode = match[1]
          if (match = line.match(/error .* requires a C\+\+11 compiler/))?
            errorMessage = match[0]
          output += "#{line}\n"
          if line.indexOf('npm http 304') is 0 then return
          if line.match(/ERR! peerinvalid .*/) then return
          @emit "npmMessage", line
          line = S(line).chompLeft('npm ').s
          npmLogger.info line
        )
        npmEnv = _.clone(process.env)
        npmEnv['HOME'] = require('path').resolve @framework.maindir, '../..'
        npmEnv['NPM_CONFIG_UNSAFE_PERM'] = true
        ppmBin = './node_modules/pimatic/ppm.js'
        npm = spawn(ppmBin, args, {cwd: @modulesParentDir, env: npmEnv})
        stdout = byline(npm.stdout)
        stdout.on "data", onLine
        stderr = byline(npm.stderr)
        stderr.on "data", onLine

        npm.on "close", (code) =>
          @npmRunning = no
          command = ppmBin + " " + _.reduce(args, (akk, a) -> "#{akk} #{a}")
          if code isnt 0
            reject new Error(
              "Error running \"#{command}\"" + (if errorMessage? then ": #{errorMessage}" else "")
            )
          else resolve(output)

      )

    installGitPlugin: (name) ->
      return @getPluginInfo(name).then( (plugin) =>
        dist = @_findDist(plugin)
        unless dist? then throw new Error("dist package not found")
        env.logger.info("Installing: \"#{name}\" from precompiled source (#{dist.name})")
        tmpDir = path.resolve @framework.maindir, "..", ".#{name}.tmp"
        destdir = @pathToPlugin(name)

        return fs.rmrfAsync(tmpDir)
          .catch()
          .then( =>
            return download('pimatic-ci', name, dist.name, tmpDir)
          )
          .then( =>
            return fs.rmrfAsync(destdir)
              .catch()
              .then( =>
                fs.moveAsync(tmpDir, destdir)
              )
          )
          .finally( =>
            fs.rmrfAsync(tmpDir)
          )
      )

    updateGitPlugin: (name) -> @installGitPlugin(name)

    getInstalledPlugins: ->
      return fs.readdirAsync("#{@framework.maindir}/..").then( (files) =>
        return plugins =
          (f for f in files when f.match(/^pimatic-.*/)? and f isnt "pimatic-plugin-commons")
      )

    getInstalledPluginsWithInfo: ->
      return @getInstalledPlugins().then( (plugins) =>
        return pluginList = (
          for name in plugins
            packageJson = @getInstalledPackageInfo name
            name = name.replace 'pimatic-', ''
            loadedPlugin = @framework.pluginManager.getPlugin name
            listEntry = {
              name: name
              loaded: loadedPlugin?
              activated: @isActivated(name)
              description: packageJson.description
              version: packageJson.version
              homepage: packageJson.homepage
              isCompatible: @isCompatible(packageJson)
            }
        )
      )

    installUpdatesAsync: (modules) ->
      return new Promise( (resolve, reject) =>
        # resolve when complete
        @install(modules).then(resolve).catch(reject)
        # or after 10 seconds to prevent a timeout
        Promise.delay('still running', 10000).then(resolve)
      )

    getInstalledPackageInfo: (name) ->
      assert name?
      assert name.match(/^pimatic.*$/)? or name is "pimatic"
      return JSON.parse fs.readFileSync(
        "#{@pathToPlugin name}/package.json", 'utf-8'
      )

    getNpmInfo: (name) ->
      return new Promise( (resolve, reject) =>
        https.get("https://registry.npmjs.org/#{name}/latest", (res) =>
          str = ""
          res.on "data", (chunk) -> str += chunk
          res.on "end", ->
            try
              info = JSON.parse(str)
              if info.error?
                throw new Error("Getting info about #{name} failed: #{info.reason}")
              resolve info
            catch e
              reject e.message
        ).on "error", reject
      )

    loadPlugins: ->
      # Promise chain, begin with an empty promise
      chain = Promise.resolve()

      for pConf, i in @pluginsConfig
        do (pConf, i) =>
          chain = chain.then( () =>
            assert pConf?
            assert pConf instanceof Object
            assert pConf.plugin? and typeof pConf.plugin is "string"

            if pConf.active is false
              return Promise.resolve()

            fullPluginName = "pimatic-#{pConf.plugin}"
            return Promise.try( =>
              # If the plugin folder already exist
              return (
                if @isInstalled(fullPluginName) then Promise.resolve()
                else
                  @installPlugin(fullPluginName)
              ).then( =>
                pluginName = @extractPluginName(fullPluginName)
                return @loadPlugin(pluginName, pConf).then( ([plugin, packageInfo]) =>
                  # Check config
                  configSchema = @_getConfigSchemaFromPackageInfo(packageInfo)
                  if typeof plugin.prepareConfig is "function"
                    plugin.prepareConfig(pConf)
                  if configSchema?
                    @framework._validateConfig(pConf, configSchema, "config of #{pluginName}")
                    pConf = declapi.enhanceJsonSchemaWithDefaults(configSchema, pConf)
                  else
                    env.logger.warn(
                      "package.json of \"#{pluginName}\" has no \"configSchema\" property. " +
                      "Could not validate config."
                    )
                  @registerPlugin(plugin, pConf, configSchema)
                )
              )
            )
          ).catch( (error) ->
            # If an error occurs log an ignore it.
            env.logger.error error.message
            env.logger.debug error.stack
          )

      return chain

    _getConfigSchemaFromPackageInfo: (packageInfo) ->
      unless packageInfo.configSchema?
        return null
      pathToSchema = path.resolve(
        @pathToPlugin(packageInfo.name),
        packageInfo.configSchema
      )
      configSchema = require(pathToSchema)
      unless configSchema._normalized
        configSchema.properties.plugin = {
          type: "string"
        }
        configSchema.properties.active = {
          type: "boolean"
          required: false
        }
        @framework._normalizeScheme(configSchema)
      return configSchema

    initPlugins: ->
      for plugin in @plugins
        try
          plugin.plugin.init(@framework.app, @framework, plugin.config)
        catch err
          env.logger.error(
            "Could not initialize the plugin \"#{plugin.config.plugin}\": " +
            err.message
          )
          env.logger.debug err.stack

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

    getPluginConfig: (name) ->
      for plugin in @framework.config.plugins
        if plugin.plugin is name then return plugin
      return null

    isActivated: (name) ->
      for plugin in @framework.config.plugins
        if plugin.plugin is name
          return if plugin.active? then plugin.active else true
      return false

    getPluginConfigSchema: (name) ->
      assert name?
      assert typeof name is "string"
      packageInfo = @getInstalledPackageInfo(name)
      return @_getConfigSchemaFromPackageInfo(packageInfo)

    updatePluginConfig: (pluginName, config) ->
      assert pluginName?
      assert typeof pluginName is "string"
      config.plugin = pluginName
      fullPluginName = "pimatic-#{pluginName}"
      configSchema = @getPluginConfigSchema(fullPluginName)
      if configSchema?
        @framework._validateConfig(config, configSchema, "config of #{fullPluginName}")
      for plugin, i in @framework.config.plugins
        if plugin.plugin is pluginName
          @framework.config.plugins[i] = config
          @framework.emit 'config'
          return
      @framework.config.plugins.push(config)
      @framework.emit 'config'

    removePluginFromConfig: (pluginName) ->
      removed = _.remove(@framework.config.plugins, (p) => p.plugin is pluginName)
      if removed.length > 0
        @framework.emit 'config'
      return removed.length > 0

    setPluginActivated: (pluginName, active) ->
      for plugin, i in @framework.config.plugins
        if plugin.plugin is pluginName
          if !!plugin.active isnt !!active
            @requrieRestart()
          plugin.active = active
          @framework.emit 'config'
          return true
      return false

    getCallingPlugin: () ->
      stack = new Error().stack.toString()
      matches = stack.match(/^.+?\/node_modules\/(pimatic-.+?)\//m)
      if matches?
        return matches[1]
      else
        return 'pimatic'

    requrieRestart: () ->
      @restartRequired = true

    doesRequireRestart: () ->
      return @restartRequired


  class Plugin extends require('events').EventEmitter
    name: null
    init: ->
      throw new Error("Your plugin must implement init")

    #createDevice: (config) ->

  return exports = {
    PluginManager
    Plugin
  }
