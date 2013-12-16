assert = require "cassert"

describe "pimatic", ->

  config =   
    settings:
      locale: "en"
      authentication:
        username: "test"
        password: "test"
        enabled: true
        disabled: true
      logLevel: "error"
      httpServer:
        enabled: true
        port: 8080
      httpsServer:
        enabled: false
      plugins: []
      actuators: []
      rules: []

  fs = require 'fs'
  os = require 'os'
  configFile = "#{os.tmpdir()}/pimatic-test-config.json"

  before ->
    fs.writeFile configFile, JSON.stringify(config), (err) ->
      throw err  if err
    process.env.PIMATIC_CONFIG = configFile

  after ->
    fs.unlinkSync configFile

  describe 'startup', ->

    it "should startup", ->
      require '../startup'

    it "httpServer should run", (done)->
      http = require 'http'
      http.get("http://localhost:#{config.settings.httpServer.port}", (res) ->
        done()
      ).on "error", (e) ->
        throw e

    it "httpServer should ask for password", (done)->
      http = require 'http'
      http.get("http://localhost:#{config.settings.httpServer.port}", (res) ->
        assert res.statusCode is 401 # is Unauthorized
        done()
      ).on "error", (e) ->
        throw e