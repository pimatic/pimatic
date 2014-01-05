npm = require 'npm'
fs = require 'fs'
path = require 'path'
Q = require 'q'
util = require 'util'
logger = require './logger'
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
          # just installing the dependencies
          @installDependencies name
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
      return Q.ninvoke(npm, 'install')
    )

  # Install a plugin from the npm repository
  installPlugin: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return @_getNpm().then( (npm) =>
      npm.prefix = @modulesParentDir
      return Q.ninvoke(npm, 'install', name)
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
      return Q.ninvoke(npm, 'search', 'pimatic-')
    )

  isPimaticOutdated: ->
    return @_getNpm().then( (npm) =>
      # outdated does only work, if pimatic is installed as node module
      if path.basename(path.resolve @framework.maindir,  ) isnt 'node_modules'
        throw new Error('pimatic is not in an node_modules folder. Update check does not work.')
      # set prefix to the parent directory of the node_modules folder
      npm.prefix = @modulesParentDir
      return Q.ninvoke(npm, 'outdated', 'pimatic').then( (result)->
        if result.length is 1
          result = result[0]
          return info =
            current: result[2]
            latest: result[3]
        else return false
      )
    )

  arePluginsOutdated: ->
    return @_getNpm().then( (npm) =>
      return @getInstalledPlugins( (plugins) =>
        return Q.ninvoke(npm, 'outdated', plugins...)
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
          logger.log(msg.level, msg.prefix, msg.message)
        else
          logger.info("npm #{msg.level}", msg.prefix, msg.message)

      return npm
    )

  getInstalledPlugins: ->
    return Q.nfcall(fs.readdir, "#{@framework.maindir}").then( (modules) =>
      return plugins = (module for module in modules when module.match(/^pimatic-.*/)?)
    ) 

  getInstalledPackageInfo: (name) ->
    assert name?
    assert name.match(/^pimatic-.*$/)?
    return JSON.parse fs.readFileSync(
      "#{@path name}/package.json", 'utf-8'
    )


class Plugin extends require('events').EventEmitter
  name: null
  init: ->
    throw new Error("your plugin must implement init")

  #createActuator: (config) ->

  #createSensor: (config) ->

module.exports.PluginManager = PluginManager
module.exports.Plugin = Plugin