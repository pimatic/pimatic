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

  framework = null
  actuatorConfig = null

  describe 'startup', ->

    it "should startup", ->
      framework = (require '../startup').framework

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

  describe '#addActuatorToConfig()', ->

    actuatorConfig = 
      id: 'test-actuator'
      class: 'TestActuatorClass'

    it 'should add the actuator to the config', ->

      framework.addActuatorToConfig actuatorConfig
      assert framework.config.actuators.length is 1
      assert framework.config.actuators[0].id is actuatorConfig.id

    it 'should throw an error if the actuator exists', ->
      try
        framework.addActuatorToConfig actuatorConfig
        assert false
      catch e
        assert e.message is "an actuator with the id #{actuatorConfig.id} is already in the config"

  describe '#isActuatorInConfig()', ->

    it 'should find actuator in config', ->
      assert framework.isActuatorInConfig actuatorConfig.id

    it 'should not find antother actuator in config', ->
      assert not framework.isActuatorInConfig 'a-not-present-id'


  describe '#updateActuatorConfig()', ->

    actuatorConfigNew = 
      id: 'test-actuator'
      class: 'TestActuatorClass'
      test: 'bla'


    it 'should update actuator in config', ->
      framework.updateActuatorConfig actuatorConfigNew
      assert framework.config.actuators[0].test is 'bla'

