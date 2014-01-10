assert = require "cassert"
Q = require 'q'
os = require 'os'
fs = require 'fs.extra'


describe "PluginManager", ->

  env = 
    plugins: require '../lib/plugins'
    logger: require '../lib/logger'

  env.logger.info = ->

  frameworkDummy =
    maindir: "#{os.tmpdir()}/pimatic-test/node_modules/pimatic"

  pluginManager = null
  skip = not process.env['NPM_TESTS']

  before ->
    # make the temp dir:
    fs.mkdirpSync frameworkDummy.maindir

  after ->
    # make the temp dir:
    fs.rmrfSync "#{os.tmpdir()}/pimatic-test"

  describe '#construct()', ->

    it 'should construct the PluginManager', ->
      pluginManager = new env.plugins.PluginManager env, frameworkDummy

  describe '#pathToPlugin()', ->

    it "should return #{os.tmpdir()}/pimatic-test/node_modules/pimatic-test", ->
      path = pluginManager.pathToPlugin('pimatic-test')
      assert path is "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-test"

  describe '#installPlugin()', ->

    it 'should install the plugin from npm',  unless skip then (finish) ->
      this.timeout 20000
      pluginManager.installPlugin('pimatic-cron').then( ->
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron"
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
        finish()
      ).done()

  describe '#installDependencies()', ->

    it 'should install the plugin dependencies',  unless skip then (finish) ->
      this.timeout 20000
      fs.rmrfSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
      pluginManager.installPlugin('pimatic-cron').then( ->
        assert fs.existsSync "#{os.tmpdir()}/pimatic-test/node_modules/pimatic-cron/node_modules"
        finish()
      ).done()

  describe '#getInstalledPlugins()', ->

    it 'should return the pimatic-cron plugin',  unless skip then (finish) ->
      pluginManager.getInstalledPlugins().then( (names) ->
        assert names.length is 1
        assert names[0] is 'pimatic-cron'
        finish()
      ).done()

  describe '#getInstalledPackageInfo()', ->

    it 'should return pimatic-crons package.json',  unless skip then  ->
      pkgInfo = pluginManager.getInstalledPackageInfo('pimatic-cron')
      assert pkgInfo.name is 'pimatic-cron' 

 configFile = "#{os.tmpdir()}/pimatic-test-config.json"