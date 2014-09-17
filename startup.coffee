# #Framwork start up

assert = require 'cassert'
fs = require 'fs'
path = require 'path'
Promise = require 'bluebird'

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
    # PIMATIC_CONFIG envirement variable if it is set
    if process.env.PIMATIC_CONFIG? then process.env.PIMATIC_CONFIG 
    # or get the config the parent folder of node_modules
    else path.resolve __dirname, '../../config.json'
  )

  # Setup the framework
  env.framework = (require './lib/framework') env 
  Promise.try( =>
    framework = new env.framework.Framework configFile
    promise = framework.init()
    return promise.then( => framework )
  ).catch( (e) =>
    env.logger.error e.message
    env.logger.debug e.stack
    throw e
  )

module.exports.startup = startup
module.exports.env = env