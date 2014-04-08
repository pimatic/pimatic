###
Logger
======


###
winston = require 'winston'
events = require("events")
util = require("util")
CBuffer = require 'CBuffer'


class MemoryTransport extends winston.Transport

  name: "memory"
  bufferLength: 1000
  errorCount: 0
  nextId: 0

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
    now = new Date()
    msg =   
      id: "#{now.getTime()}-#{@nextId++}"
      level: level
      msg: msg
      meta: meta
      time: now.format 'YYYY-MM-DD hh:mm:ss'
    @buffer.push msg
    @emit "logged"
    @emit "log", msg
    callback null, true

logger = new (winston.Logger)(
  transports: [
    new (winston.transports.Console)(
      level: 'debug'
      colorize: not process.env['PIMATIC_DAEMONIZED']?
      timestamp: -> new Date().format 'YYYY-MM-DD hh:mm:ss'
    ),
    new MemoryTransport()
  ]
)

module.exports = logger