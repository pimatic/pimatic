# #Framwork start up

assert = require 'cassert'
fs = require 'fs'

# Setup the environment
env =
  logger: require './lib/logger'
  helper: require './lib/helper'
  actuators: require './lib/actuators'
  sensors: require './lib/sensors'
  rules: require './lib/rules'
  plugins: require './lib/plugins'
  actions: require './lib/actions'

configFile = if process.env.PIMATIC_CONFIG? then process.env.PIMATIC_CONFIG else "./config.json"

# Setup the framework
Framework = (require './lib/framework') env 
framework = new Framework configFile
promise = framework.init()
promise.done()

module.exports.framework = framework