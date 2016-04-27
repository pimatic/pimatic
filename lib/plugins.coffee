
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
spawn = require("cross-spawn").spawn
https = require "https"
semver = require "semver"
events = require 'events'
S = require 'string'
declapi = require 'decl-api'
rp = require 'request-promise'
download = require 'gethub'

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

    constructor: (@framework) ->
      @modulesParentDir = path.resolve @framework.maindir, '../../'

    checkNpmVersion: () ->
      @spawnNpm(['--version']).then( (result) =>
        version = result.trim()
        unless semver.satisfies(version, '<3')
          env.logger.warn(
            "pimatic needs npm version 2, your version is #{version}, run \"npm install -g npm@2\"."
          )
      ).catch( (err) =>
        env.logger.warn("Could not run npm, plugin and module installation will not work.")
      )

    # Loads the given plugin by name
    loadPlugin: (name) ->
      packageInfo = @getInstalledPackageInfo(name)
      packageInfoStr = (if packageInfo? then "(" + packageInfo.version  + ")" else "")
      env.logger.info("""Loading plugin: "#{name}" #{packageInfoStr}""")
      # require the plugin and return it
      # create a sublogger:
      pluginEnv = Object.create(env)
      pluginEnv.logger = env.logger.base.createSublogger(name)
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
            return @spawnNpm(['update', name, '--unsafe-perm'])
          else
            return @spawnNpm(['install', name, '--unsafe-perm'])
        dist = @_findDist(packageInfo)
        if dist
          return if update then @updateGitPlugin(name) else @installGitPlugin(name)
        env.logger.info("Installing: \"#{name}@#{packageInfo.version}\" from npm-registry.")
        return @spawnNpm(['install', "#{name}@#{packageInfo.version}", '--unsafe-perm'])
      )

    updatePlugin: (name) ->
      return @installPlugin(name, true)

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

    update: (modules) ->
      info = {modules}
      @_emitUpdateProcessStatus('running', info)
      npmMessageListener = ( (line) => @_emitUpdateProcessMessage(line, info); )
      @on 'npmMessage', npmMessageListener
      hasErrors = false
      return Promise.each(modules, (plugin) =>
        @updatePlugin(plugin).catch( (error) =>
          env.logger.error("Error Updating plugin #{plugin}: #{error.message}")
          env.logger.debug(error.stack)
        )
      ).then( =>
        @_emitUpdateProcessStatus('done', info)
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
      return path.resolve @framework.maindir, "..", name

    getPluginList: ->
      if @_pluginList then return @_pluginList
      else return @searchForPlugin()

    getCoreInfo: ->
      if @_coreInfo then return @_coreInfo
      else return @searchForCoreUpdate()

    searchForPlugin: ->
      return @_pluginList = rp('http://api.pimatic.org/plugins').then( (res) =>
        json = JSON.parse(res)
        # cache for 1min
        setTimeout( (=> @_pluginList = null), 60*1000)
        return json
      )

    searchForCoreUpdate: ->
      return @_coreInfo = rp('http://api.pimatic.org/core').then( (res) =>
        json = JSON.parse(res)
        # cache for 1min
        setTimeout( (=> @_coreInfo = null), 60*1000)
        return json
      )

    getPluginInfo: (name) ->
      return @getCoreInfo() if name is "pimatic"
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
          throw new Error("Error getting info about #{name} from npm failed: #{info.reason}")
        return getLatestCompatible(packageInfos, @framework.packageJson.version)
      )

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
              active: loadedPlugin?
              isNewer: (if installed then semver.gt(p.version, packageJson.version) else false)
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
          if semver.gt(p.latest, p.current)
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

    spawnNpm: (args) ->
      return new Promise( (resolve, reject) =>
        if @npmRunning
          reject "npm is currently in use"
          return
        @npmRunning = yes
        output = ''
        npmLogger = env.logger.createSublogger("npm")
        onLine = ( (line) =>
          line = line.toString()
          output += "#{line}\n"
          if line.indexOf('npm http 304') is 0 then return
          @emit "npmMessage", line
          line = S(line).chompLeft('npm ').s
          npmLogger.info line
        )
        npmEnv = _.clone(process.env)
        npmEnv['HOME'] = require('path').resolve @framework.maindir, '../..'
        npmEnv['NPM_CONFIG_UNSAFE_PERM'] = true
        npm = spawn('npm', args, {cwd: @modulesParentDir, env: npmEnv})
        stdout = byline(npm.stdout)
        stdout.on "data", onLine
        stderr = byline(npm.stderr)
        stderr.on "data", onLine

        npm.on "close", (code) =>
          @npmRunning = no
          command = "npm " + _.reduce(args, (akk, a) -> "#{akk} #{a}")
          if code isnt 0
            reject new Error("Error running \"#{command}\"")
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
        return plugins = (f for f in files when f.match(/^pimatic-.*/)?)
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
              active: loadedPlugin?
              description: packageJson.description
              version: packageJson.version
              homepage: packageJson.homepage
            }
        )
      )

    installUpdatesAsync: (modules) ->
      return new Promise( (resolve, reject) =>
        # resolve when complete
        @update(modules).then(resolve).catch(reject)
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
                return @loadPlugin(fullPluginName).then( ([plugin, packageInfo]) =>
                  # Check config
                  if packageInfo.configSchema?
                    pathToSchema = path.resolve(
                      @pathToPlugin(fullPluginName),
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
                    if typeof plugin.prepareConfig is "function"
                      plugin.prepareConfig(pConf)
                    @framework._validateConfig(pConf, configSchema, "config of #{fullPluginName}")
                    pConf = declapi.enhanceJsonSchemaWithDefaults(configSchema, pConf)
                  else
                    env.logger.warn(
                      "package.json of \"#{fullPluginName}\" has no \"configSchema\" property. " +
                      "Could not validate config."
                    )
                  @registerPlugin(plugin, pConf, configSchema)
                )
              )
            )
          ).catch( (error) ->
            # If an error occures log an ignore it.
            env.logger.error error.message
            env.logger.debug error.stack
          )

      return chain

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

    addPluginsToConfig: (plugins) ->
      Array.isArray pluginNames
      pluginNames = (p.plugin for p in @pluginsConfig)
      added = []
      for p in plugins
        unless p in pluginNames
          @pluginsConfig.push {plugin: p}
          added.push p
      @framework.saveConfig()
      return added

    removePluginsFromConfig: (plugins) ->
      removed = _.remove(@pluginsConfig, (p) -> p.plugin in plugins)
      @framework.saveConfig()
      return removed


  class Plugin extends require('events').EventEmitter
    name: null
    init: ->
      throw new Error("Your plugin must implement init")

    #createDevice: (config) ->

  return exports = {
    PluginManager
    Plugin
  }
