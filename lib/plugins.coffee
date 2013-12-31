npm = require 'npm'
fs = require 'fs'
Q = require 'q'
util = require 'util'
logger = require './logger'

class PluginManager

  # Loads the given plugin by name
  loadPlugin: (env, name) ->
 
    return Q.fcall =>     
      # If the plugin folder already exist
      promise = 
        if @existsPlugin name 
          # just installing the dependencies
          @installDependencies name
        else 
          # otherwise install the plugin from the npm repository
          @installPlugin name

      # After installing
      return promise.then( ->
        # require the plugin and return it
        return plugin = (require name) env
      )
  # Checks if the plugin folder exists under node_modules
  existsPlugin: (name) ->
    return fs.existsSync(@path name)

  # Install the plugin dependencies for an existing plugin folder
  installDependencies: (name, cwd) ->
    return @_loadNpm().then( (npm) =>
        npm.prefix = @path name
        return Q.ninvoke(npm, 'install')
      )

  # Install a plugin from the npm repository
  installPlugin: (name, cwd) ->
    return @_loadNpm().then( (npm) =>
        return Q.ninvoke(npm, 'install', name)
      )

  path: (name) ->
    return "#{process.cwd()}/node_modules/#{name}"

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
    return @_loadNpm().then( (npm) =>
      return Q.ninvoke(npm, 'search', 'pimatic-')
    )

  _loadNpm : ->
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
    return Q.nfcall(fs.readdir, "./node_modules").then( (modules) =>
      return plugins = (module for module in modules when module.match(/^pimatic-.*/)?)
    ) 


class Plugin extends require('events').EventEmitter
  name: null
  init: ->
    throw new Error("your plugin must implement init")

  #createActuator: (config) ->

  #createSensor: (config) ->

module.exports.PluginManager = PluginManager
module.exports.Plugin = Plugin