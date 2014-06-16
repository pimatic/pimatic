cassert = require "cassert"
assert = require "assert"
Q = require 'q'
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

    it "should connect", (finish) ->
      pluginManager.pluginManager = new PluginManager(frameworkDummy)
      dbSettings = {
        client: "sqlite3"
        connection: {
          filename: ':memory:'
        }
      }
      database = new env.database.Database(frameworkDummy, dbSettings)
      database.init().then( => finish() ).catch(finish)
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

      # Q.all(pending).then( ->
      #   database.queryMessages().then( (msgsResult) ->
      #     console.log msgsResult
      #     console.log msgs
      #     assert.deepEqual msgsResult, msgs
      #     finish()
      #   )
      # ).catch(finish)



