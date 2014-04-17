# #Framwork start up

assert = require 'cassert'
fs = require 'fs'
path = require 'path'
Q = require 'q'

# Setup the environment
env = { logger: require './lib/logger' }
env.devices = require('./lib/devices') env
env.matcher = require './lib/matcher'
env.variables = require('./lib/variables') env
env.actions = require('./lib/actions') env
env.predicates = require('./lib/predicates') env
env.rules = require('./lib/rules') env
env.plugins = require('./lib/plugins') env
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
  Framework = (require './lib/framework') env 
  framework = null
  try
    framework = new Framework configFile
    promise = framework.init()
    module.exports.framework = framework
    return promise.done()
  catch e
    env.logger.error e.message
    env.logger.debug e.stack
  return Q()

module.exports.startup = startup
module.exports.env = env