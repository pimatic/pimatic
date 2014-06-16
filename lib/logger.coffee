###
Logger
======


###
winston = require 'winston'

events = require("events")
util = require("util")
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

TaggedLogger = (target, tags) ->
  @target = target
  @tags = tags or []
  return @

TaggedLogger::log = (level, args...) ->
  msg = util.format.apply(null, args)
  @target.log(level, msg, {timestamp: new Date(), tags: @tags})

TaggedLogger::debug = (args...) -> @log "debug", args...
TaggedLogger::info = (args...) -> @log "info", args...
TaggedLogger::warn = (args...) -> @log "warn", args...
TaggedLogger::error = (args...) -> @log "error", args...

TaggedLogger::createSublogger = (tag) -> new TaggedLogger(@target, @tags.concat([tag]))


winstonLogger = new (winston.Logger)(
  transports: [
    new (TaggedConsoleTarget)(
      level: 'debug'
      colorize: not process.env['PIMATIC_DAEMONIZED']?
      #timestamp: -> new Date().format 'YYYY-MM-DD hh:mm:ss'
    )
  ]
)

TaggedLogger::base = base = new TaggedLogger(winstonLogger)
logger = base.createSublogger("pimatic")
logger.winston = winstonLogger
module.exports = logger