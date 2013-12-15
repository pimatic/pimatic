winston = require 'winston'
events = require("events")
util = require("util")


class MemoryTransport extends winston.Transport

  __constructor: (options) ->
	  self = this
	  Transport.call self, options

  getBuffer: ->
    self = this
    return self.buffer

MemoryTransport::name = "memory"
MemoryTransport::buffer = []
MemoryTransport::log = (level, msg, meta, callback) ->
  self = this
  msg = 	
  	level: level
  	msg: msg
  	meta: meta
  self.buffer.push msg
  self.emit "logged"
  self.emit "log", msg
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