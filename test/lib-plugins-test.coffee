assert = require "cassert"
Promise = require 'bluebird'
os = require 'os'
path = require 'path'
fs = require 'fs.extra'

env = require('../startup').env

describe "PluginManager", ->

  #env.logger.info = ->

  frameworkDummy =
    maindir: "#{os.tmpdir()}/pimatic-test/node_modules/pimatic"
    packageJson: {
      version: '0.9.53'
    }

  pluginManager = null
  skip = not process.env['NPM_TESTS']

  before ->
    # make the temp dir:
    fs.mkdirpSync frameworkDummy.maindir
    pluginManager = new env.plugins.PluginManager frameworkDummy

  after ->
    # make the temp dir:
    fs.rmrfSync "#{os.tmpdir()}/pimatic-test"

  describe '#pathToPlugin()', ->
    it "should return path to plugin", ->
      pluginPath = pluginManager.pathToPlugin('pimatic-test')
      assert pluginPath is path.normalize "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-test"

    it "should return path to plugin for specific version", ->
      pluginPath = pluginManager.pathToPlugin('pimatic-test@0.1.2')
      assert pluginPath is path.normalize "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-test"

  describe '#installPlugin()', ->
    it 'should install the plugin from npm', unless skip then (finish) ->
      this.timeout 20000
      pluginManager.installPlugin('pimatic-cron').then( ->
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron"
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
        finish()
      ).done()

    it 'should install the plugin dependencies', unless skip then (finish) ->
      this.timeout 20000
      fs.rmrfSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
      pluginManager.installPlugin('pimatic-cron').then( ->
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
        finish()
      ).done()

    it 'should install a specific plugin version', unless skip then (finish) ->
      this.timeout 20000
      fs.rmrfSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron"
      pluginManager.installPlugin('pimatic-cron@0.8.7').then( ->
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron"
        packageJson = pluginManager.getInstalledPackageInfo('pimatic-cron')
        asser packageJson.version is '0.8.7'
        finish()
      ).done()


  describe '#getInstalledPlugins()', ->
    it 'should return the pimatic-cron plugin', unless skip then (finish) ->
      pluginManager.getInstalledPlugins().then((names) ->
        assert names.length is 1
        assert names[0] is 'pimatic-cron'
        finish()
      ).done()

  describe '#getInstalledPackageInfo()', ->
    it 'should return pimatic-crons package.json', unless skip then  ->
      pkgInfo = pluginManager.getInstalledPackageInfo('pimatic-cron')
      assert pkgInfo.name is 'pimatic-cron'

  describe '#getNpmInfo()', ->
    it 'should return pimatic package info from the registry', (done) ->
      promise = pluginManager.getNpmInfo('pimatic')
      promise.then((pkgInfo) ->
        console.log "-----", pkgInfo.name is "pimatic"
        assert pkgInfo.name is "pimatic"
        done()
      ).catch(done)
      return

  describe '#extractPluginName()', ->
    it 'should remove version info from name', ->
      name = pluginManager.extractPluginName('pimatic-cron@0.8.7')
      assert name is 'pimatic-cron'

    it 'should return name if no version', ->
      name = pluginManager.extractPluginName('pimatic-cron')
      assert name is 'pimatic-cron'

  configFile = "#{os.tmpdir()}/pimatic-test-config.json"
