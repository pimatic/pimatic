cassert = require "cassert"
assert = require "assert"
Promise = require 'bluebird'
os = require 'os'
fs = require 'fs.extra'
path = require 'path'

env = require('../startup').env

describe "Database", ->

  frameworkDummy = {
    maindir: path.resolve __dirname, '../..'
    on: ->
  }
  database = null

  describe "#constructor()", ->

    it "should connect", () ->
      frameworkDummy.pluginManager = new env.plugins.PluginManager(frameworkDummy)
      dbSettings = {
        client: "sqlite3"
        connection: {
          filename: 'file::memory:?cache=private'
        }
        deviceAttributeLogging: [ 
          { deviceId: '*', attributeName: '*', expire: '7d' }
          { deviceId: '*', attributeName: 'temperature', expire: '1y' },
          { deviceId: '*', attributeName: 'humidity', expire: '1y' } 
        ]
        messageLogging: [
          { level: '*', tags: [], expire: '7d' } 
        ]
        deleteExpiredInterval: '1h',
        diskSyncInterval: '2h'
      }
      database = new env.database.Database(frameworkDummy, dbSettings)
      database.init()
  describe '#saveMessageEvent()', ->

    it "should save the messages"#, (finish) ->
      # msgs = []
      # pending = []
      # count = 20
      # for i in [0..20]
      #   msg = {
      #     time: new Date().getTime() - (20 - i)
      #     level: 'info'
      #     tags: ["pimatic", "test"]
      #     text: "text #{i}"
      #   }
      #   msgs.push msg
      #   pending.push database.saveMessageEvent(msg.time, msg.level, msg.tags, msg.text)

      # Promise.all(pending).then( ->
      #   database.queryMessages().then( (msgsResult) ->
      #     console.log msgsResult
      #     console.log msgs
      #     assert.deepEqual msgsResult, msgs
      #     finish()
      #   )
      # ).catch(finish)



