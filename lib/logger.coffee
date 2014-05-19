###
Logger
======


###
winston = require 'winston'
TaggedLogger = require("tagged-logger")

events = require("events")
util = require("util")
CBuffer = require 'CBuffer'
moment = require("moment")
require "colors"


TaggedConsoleTarget = (options) ->
  options = options or {}
  @name = "taggedConsoleLogger"
  @level = options.level or "info"
  @target = options.target or process.stdout
  @prevTimestamp = new Date()
  @target.write moment(@prevTimestamp).format("HH:mm:ss.SSS YYYY-MM-DD dddd").grey + "\n"

util.inherits TaggedConsoleTarget, winston.Transport
TaggedConsoleTarget::log = (level, msg, meta, callback) ->
  spec =
    info: {}
    warn:
      color: "yellow"
    error:
      color: "red"
    debug:
      color: "blue"
  color = spec[level].color
  meta = meta or {}
  tags = meta.tags or []
  timestamp = meta.timestamp or new Date()
  if moment(timestamp).format("YYYY-MM-DD") isnt moment(@prevTimestamp).format("YYYY-MM-DD")
    @prevTimestamp = timestamp
    @target.write moment(timestamp).format("HH:mm:ss.SSS YYYY-MM-DD dddd").grey + "\n"
  header = moment(timestamp).format("HH:mm:ss.SSS").grey + (" [" + tags.join(", ") + "]").green
  target = @target
  msg.split("\n").forEach (line, index) ->
    coloredLine = undefined
    if color
      coloredLine = line[color]
    else
      coloredLine = line
    separator = [
      " "
      ">"
    ][(if index is 0 then 0 else 1)].grey
    target.write header + separator + coloredLine + "\n"

  callback null, true

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


TaggedLogger::debug = (msg) -> @log "debug", msg

winstonLogger = new (winston.Logger)(
  transports: [
    new (TaggedConsoleTarget)(
      level: 'debug'
      colorize: not process.env['PIMATIC_DAEMONIZED']?
      #timestamp: -> new Date().format 'YYYY-MM-DD hh:mm:ss'
    ),
    new MemoryTransport()
  ]
)

TaggedLogger::base = base = new TaggedLogger(winstonLogger)

logger = base.createSublogger("pimatic")
logger.winston = winstonLogger
module.exports = logger