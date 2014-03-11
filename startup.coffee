# #Framwork start up

assert = require 'cassert'
fs = require 'fs'
path = require 'path'

# Setup the environment
env = { logger: require './lib/logger' }
env.devices = require('./lib/devices') env
env.actions = require('./lib/actions') env
env.predicates = require('./lib/predicates') env
env.rules = require('./lib/rules') env
env.plugins = require('./lib/plugins') env
env.matcher = require './lib/matcher'
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
  framework = new Framework configFile
  promise = framework.init()
  module.exports.framework = framework
  return promise.done()

module.exports.startup = startup
module.exports.env = env