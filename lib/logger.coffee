winston = require 'winston'
events = require("events")
util = require("util")
CBuffer = require 'CBuffer'


class MemoryTransport extends winston.Transport

  name: "memory"
  bufferLength: 1000
  errorCount: 0

  constructor: (options) ->
    @buffer = new CBuffer(@bufferLength)
    winston.Transport.call @, options

  getBuffer: ->
    return @buffer.toArray()

  getErrorCount: -> @errorCount

  clearLog: ->
    @buffer.empty()
    @errorCount = 0

  clearErrorCount: -> 
    @errorCount = 0
    return

  log: (level, msg, meta, callback) ->
    if level is 'error' then @errorCount++
    msg =   
      level: level
      msg: msg
      meta: meta
    @buffer.push msg
    @emit "logged"
    @emit "log", msg
    callback null, true



logger = new (winston.Logger)(
  transports: [
    new (winston.transports.Console)(
      level: 'debug'
      colorize: true
    ),
    new MemoryTransport()
  ]
)

module.exports = logger