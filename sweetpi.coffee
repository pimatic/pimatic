# #Framwork start up
# 
# * Reads the config file
# * Creates a [exprees](http://expressjs.com/) app
# * Starts the http- and https-server

# 
assert = require 'cassert'
express = require "express"
fs = require 'fs'
convict = require 'convict'
i18n = require 'i18n'

# Setup the environment
env =
  logger: require './lib/logger'
  helper: require './lib/helper'
  actuators: require './lib/actuators'
  sensors: require './lib/sensors'
  rules: require './lib/rules'
  plugins: require './lib/plugins'


# ##Load the configuration file.
# 
# * Uses `node-convict` for config loading. All config options are in the 
#   [config-shema](config-shema.html) file.
conf = convict require("./config-shema")
conf.loadFile "./config.json"
# * Performs the validation.
conf.validate()
config = conf.get("")

i18n.configure({
  locales:['en', 'de'],
  directory: __dirname + '/locales',
  defaultLocale: config.server.locale,
})


# Setup express
# -------------
app = express()
app.use i18n.init
#app.use express.logger()
app.use express.bodyParser()

# Setup authentication
# ----------------------
# Use http-basicAuth if authentication is not disabled.
auth = config.server.authentication
if auth.enabled
  #Check authentication.
  env.helper.checkConfig 'server.authentication', ->
    assert auth.username and typeof auth.username is "string" and auth.username.length isnt 0 
    assert auth.password and typeof auth.password is "string" and auth.password.length isnt 0 
  app.use express.basicAuth(auth.username, auth.password)

if not config.server.httpsServer?.enabled and not config.server.httpServer?.enabled
  env.logger.warn "You have no https and no http server defined!"

# Start the https-server if it is enabled.
if config.server.httpsServer?.enabled
  httpsConfig = config.server.httpsServer
  env.helper.checkConfig 'server', ->
    assert httpsConfig instanceof Object
    assert typeof httpsConfig.keyFile is 'string' and httpsConfig.keyFile.length isnt 0
    assert typeof httpsConfig.certFile is 'string' and httpsConfig.certFile.length isnt 0 

  httpsOptions = {}
  httpsOptions[name]=value for name, value of httpsConfig
  httpsOptions.key = fs.readFileSync httpsConfig.keyFile
  httpsOptions.cert = fs.readFileSync httpsConfig.certFile
  https = require "https"
  app.httpsServer = https.createServer httpsOptions, app

# Start the http-server if it is enabled.
if config.server.httpServer?.enabled
  http = require "http"
  app.httpServer = http.createServer app



# Setup the server
# ----------------
Server = (require './lib/server') env 

server = new Server app, config
server.init()

if app.httpsServer?
  app.httpsServer.listen config.server.httpsServer.port
  env.logger.info "listening for https-request on port #{config.server.httpsServer.port}..."

if app.httpServer?
  app.httpServer.listen config.server.httpServer.port
  env.logger.info "listening for http-request on port #{config.server.httpServer.port}..."
