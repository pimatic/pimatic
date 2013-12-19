npm = require 'npm'
fs = require 'fs'

class PluginManager

  loadPlugin: (env, name, cb) ->
    self = this
    cwd = process.cwd()

    onComplete = (err) ->
      if (err) 
        env.logger.error err
      else plugin = (require name) env
      process.chdir cwd
      cb err, plugin

    if self.existsPlugin name
      self.installDependencies name, onComplete
    else self.installPlugin name, onComplete

  existsPlugin: (name) ->
    self = this
    return fs.existsSync(self.path name)

  installDependencies: (name, cb) ->
    self = this
    npm.load {}, (er, npm) ->
      npm.prefix = self.path name
      npm.install cb

  installPlugin: (name, cb) ->
    npm.load {}, (er, npm) ->
      npm.install name, cb

  path: (name) ->
    return "#{process.cwd()}/node_modules/#{name}"

class Plugin
  name: null
  init: ->
    throw new Error("your plugin must implement init")

  #createActuator: (config) ->

  #createSensor: (config) ->

module.exports.PluginManager = PluginManager
module.exports.Plugin = Plugin