# #Framwork start up
# 
# * Reads the config file
# * Creates a [exprees](http://expressjs.com/) app
# * Starts the http- and https-server

# 
should = require 'should'
express = require "express"
fs = require "fs"
convict = require "convict"
helper = require './lib/helper'
Server = require "./lib/server"

# ##Load the configuration file.
# 
# * Uses `node-convict` for config loading. All config options are in the 
#   [config-shema](config-shema.html) file.
conf = convict require("./config-shema")
conf.loadFile "./config.json"
# * Performs the validation.
conf.validate()
config = conf.get("");

# Setup express
# -------------
app = express()
app.use express.logger()


# Setup authentication
# ----------------------
# Use http-basicAuth if authentication is not disabled.
auth = config.server.authentication
if auth.enabled
  #Check authentication.
  helper.checkConfig 'server.authentication', ->
    auth.should.have.property("username").be.a('string').not.empty
    auth.should.have.property("password").be.a('string').not.empty

  app.use express.basicAuth(auth.username, auth.password)

# Setup the server
# ----------------
server = new Server app, config
server.init()

if not config.server.httpsServer?.enabled and not config.server.httpServer?.enabled
  console.warn "You have no https and no http server defined!"

# Start the https-server if it is enabled.
if config.server.httpsServer?.enabled
  helper.checkConfig 'server', ->
    config.server.should.have.property("httpsServer").be.a('object')
    config.server.httpsServer.should.have.property("port").be.a 'number'
    config.server.httpsServer.should.have.property("keyFile").be.a('string').not.empty
    config.server.httpsServer.should.have.property("certFile").be.a('string').not.empty

  config.server.httpsServer.key = fs.readFileSync config.server.httpsServer.keyFile
  config.server.httpsServer.cert = fs.readFileSync config.server.httpsServer.certFile
  https = require "https"
  https.createServer(config.server.httpsServer, app).listen config.server.httpsServer.port
  console.log "listening for https-request on port #{config.server.httpsServer.port}..."

# Start the http-server if it is enabled.
if config.server.httpServer?.enabled
  helper.checkConfig 'server', ->
    config.server.should.have.property("httpServer").should.be.a 'object'
    config.server.httpServer.should.have.property("port").be.a 'number'
     
  http = require "http"
  http.createServer(app).listen config.server.httpServer.port
  console.log "listening for http-request on port #{config.server.httpServer.port}..."
