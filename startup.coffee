# #Framework start up

assert = require 'cassert'
fs = require 'fs'
path = require 'path'
Promise = require 'bluebird'
# Enable this for better stack traces: 
# https://github.com/petkaantonov/bluebird/blob/master/API.md#promiselongstacktraces---void
#Promise.longStackTraces()

# Setup the environment
env = { logger: require './lib/logger' }
env.api = require('./lib/api')
env.users = require('./lib/users') env
env.devices = require('./lib/devices') env
env.matcher = require './lib/matcher'
env.variables = require('./lib/variables') env
env.actions = require('./lib/actions') env
env.predicates = require('./lib/predicates') env
env.rules = require('./lib/rules') env
env.plugins = require('./lib/plugins') env
env.database = require('./lib/database') env
env.groups = require('./lib/groups') env
env.pages = require('./lib/pages') env
env.require = (args...) -> module.require args...

startup = =>
  # set the config file to
  configFile = (
    # PIMATIC_CONFIG environment variable if it has been set up
    if process.env.PIMATIC_CONFIG? then process.env.PIMATIC_CONFIG 
    # or get the configuration parent folder of node_modules
    else path.resolve __dirname, '../../config.json'
  )

  exit = (code) ->  
    env.logger.info "exiting..."
    if process.logStream?
      # close logstream first
      process.stdout.write = process.stdout.writeOut
      process.stderr.write = process.stderr.writeOut
      process.logStream.writer.on 'finish', ->
        process.exit(code)
      process.logStream.end()
    else
      process.exit(code)

  # Setup the framework
  env.framework = (require './lib/framework') env 
  return Promise.try( =>
    framework = new env.framework.Framework configFile
    promise = framework.init().then( ->

      onKill = -> 
        framework.destroy().then( -> exit(0) )

      uncaughtException = (err) ->
        unless err.silent
          env.logger.error(
            "A uncaught exception occured: #{err.stack}\n
             This is most probably a bug in pimatic or in a module, please report it!"
          )
        if process.env['PIMATIC_DAEMONIZED']
          env.logger.warn(
            "Keeping pimatic alive, but could be in an undefined state, 
             please restart pimatic as soon as possible!"
          )
        else
          env.logger.warn("shutting pimatic down...")
          framework.destroy().then( -> exit(1) )

      process.on('SIGINT', onKill)
      process.on('SIGTERM', onKill)
      process.on('uncaughtException', uncaughtException)
    )

    return promise.then( => framework )
  ).catch( (err) =>
    unless err.silent
      env.logger.error "Startup error: #{err.stack}"
    exit(1)
  )

module.exports.startup = startup
module.exports.env = env
