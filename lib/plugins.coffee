npm = require 'npm'
fs = require 'fs'
path = require 'path'
Q = require 'q'
util = require 'util'
assert = require 'cassert'

env = null

class PluginManager

  constructor: (_env, @framework) ->
    env = _env
    @modulesParentDir = path.resolve @framework.maindir, '../../'

  # Loads the given plugin by name
  loadPlugin: (name) ->
    return Q.fcall =>     
      # If the plugin folder already exist
      promise = 
        if @isInstalled name 
          # We could instal the depencies...
          # @installDependencies name
          # but it takes so long
          Q()
        else 
          # otherwise install the plugin from the npm repository
          @installPlugin name

      # After installing
      return promise.then( =>
        # require the plugin and return it
        return plugin = (require name) env, module
      )
  # Checks if the plugin folder exists under node_modules
  isInstalled: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return fs.existsSync(@pathToPlugin name)

  # Install the plugin dependencies for an existing plugin folder
  installDependencies: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return @_getNpm().then( (npm) =>
      npm.prefix = @pathToPlugin name
      return Q.ninvoke(npm.commands, 'install', [])
    )

  # Install a plugin from the npm repository
  installPlugin: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return @_getNpm().then( (npm) =>
      npm.prefix = @modulesParentDir
      return Q.ninvoke(npm.commands, 'install', [name])
    )

  update: (modules) -> 
    return @_getNpm().then( (npm) =>
      npm.prefix = @modulesParentDir
      return Q.ninvoke(npm.commands, 'update', modules)
    )

  pathToPlugin: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return path.resolve @framework.maindir, "..", name

  # Returns plugin list of the form:  
  # 
  #     {
  #      'pimatic-cron': 
  #       { name: 'pimatic-cron',
  #         description: 'cron plugin for pimatic',
  #         maintainers: [ '=sweetpi' ],
  #         url: null,
  #         keywords: [],
  #         version: '0.3.2',
  #         time: '2013-12-30 09:16',
  #         words: 'pimatic-cron cron plugin for pimatic =sweetpi' },
  #      'pimatic-filebrowser': 
  #       { name: ...
  #       }
  #      ...
  #     }
  # 
  searchForPlugins: ->
    return @_getNpm().then( (npm) =>
      return Q.ninvoke(npm.commands, 'search', ['pimatic-'], true)
    )

  isPimaticOutdated: ->
    return @_getNpm().then( (npm) =>
      # outdated does only work, if pimatic is installed as node module
      if path.basename(path.resolve @framework.maindir, '..' ) isnt 'node_modules'
        throw new Error('pimatic is not in an node_modules folder. Update check does not work.')
      # set prefix to the parent directory of the node_modules folder
      npm.prefix = @modulesParentDir
      return Q.ninvoke(npm.commands, 'outdated', ['pimatic'], true).then( (result) =>
        if result.length is 1
          result = result[0]
          return info =
            current: result[2]
            latest: result[3]
        else return false
      )
    )

  getOutdatedPlugins: ->
    return @_getNpm().then( (npm) =>
      return @getInstalledPlugins().then( (plugins) =>
        npm.prefix = @modulesParentDir
        return Q.ninvoke(npm.commands, 'outdated', plugins, true).then( (result) =>
          return (for r in result
            entry =
              plugin: r[1]
              current: r[2]
              latest: r[3]
          )
        )
      )
    )
    
  _getNpm: ->
    return (
      if @npm then Q.fcall => @npm
      else @_loadNpm().then (npm) => @npm = npm
    ).then( (npm) =>
      # Reset prefix to maindir
      @npm.prefix = @modulesParentDir
      return npm
    )

  
  _loadNpm: ->
    return Q.ninvoke(npm, 'load', options = {}).then( (npm) =>

      # console.log util.inspect(npm,
      #   showHidden: true
      #   depth: 2
      # )
      # Don't log to stdout or stderror:
      npm.registry.log.pause()
      # Proxy the log stream to our own log:
      npm.registry.log.on 'log', (msg) ->
        if msg.level is 'info' or msg.level is 'verbose' or msg.level is 'silly' then return
        if msg.level is 'error' 
          env.logger.log(msg.level, msg.prefix, msg.message)
        else
          env.logger.info("npm #{msg.level}", msg.prefix, msg.message)
      return npm
    )

  getInstalledPlugins: ->
    return Q.nfcall(fs.readdir, "#{@framework.maindir}/..").then( (files) =>
      return plugins = (f for f in files when f.match(/^pimatic-.*/)?)
    ) 

  getInstalledPackageInfo: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return JSON.parse fs.readFileSync(
      "#{@pathToPlugin name}/package.json", 'utf-8'
    )


class Plugin extends require('events').EventEmitter
  name: null
  init: ->
    throw new Error("your plugin must implement init")

  #createDevice: (config) ->

module.exports.PluginManager = PluginManager
module.exports.Plugin = Plugin