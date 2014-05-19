cassert = require "cassert"
assert = require "assert"
Q = require 'q'
os = require 'os'
fs = require 'fs.extra'

env = require('../startup').env

describe "Eventlog", ->

  frameworkDummy = {}
  eventlog = null

  describe "#constructor()", ->

    it "should connect", (finish) ->
      dbSettings = {
        client: "sqlite3"
        connection: {
          filename: ':memory:'
        }
      }
      eventlog = new env.events.Eventlog(frameworkDummy, dbSettings)
      eventlog.once('ready', finish)

  describe '#saveMessageEvent()', ->

    it "should save the messages", (finish) ->
      msgs = []
      pending = []
      count = 20
      for i in [0..20]
        msg = {
          time: new Date().getTime() - (20 - i)
          level: 'info'
          text: "text #{i}"
          tags: ["pimatic", "test"]
        }
        msgs.push msg
        pending.push eventlog.saveMessageEvent(msg.time, msg.level, msg.tags, msg.text)

      Q.all(pending).then( ->
        eventlog.queryMessages().then( (msgsResult) ->
          assert.deepEqual msgsResult, msgs
          finish()
        )
      ).catch(finish)



