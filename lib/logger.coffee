###
Logger
======


###
winston = require 'winston'
_ = require 'lodash'
events = require("events")
util = require("util")
moment = require("moment")
colors = require "colors"

TaggedConsoleTarget = (options) ->
  options = options or {}
  @name = "taggedConsoleLogger"
  @level = options.level or "info"
  @target = options.target or process.stdout
  @colorize = options.colorize
  @prevTimestamp = new Date()
  timeString = moment(@prevTimestamp).format("HH:mm:ss.SSS YYYY-MM-DD dddd")
  if @colorize then timeString = timeString.grey
  @target.write timeString + "\n"

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
    timeString = moment(@prevTimestamp).format("HH:mm:ss.SSS YYYY-MM-DD dddd")
    if @colorize then timeString = timeString.grey
  timeString = moment(timestamp).format("HH:mm:ss.SSS")
  tags = " [" + tags.join(", ") + "]"
  if @colorize
    timeString = timeString.grey
    tags = tags.green
    header = timeString + tags
  else
    header = "#{timeString}#{tags} #{level}:"
  target = @target

  msg.split("\n").forEach (line, index) =>
    coloredLine = undefined
    if color and @colorize
      coloredLine = line[color]
    else
      coloredLine = line
    separator = [" ", ">"][(if index is 0 then 0 else 1)]
    if @colorize then separator = separator.grey
    target.write header + separator + coloredLine + "\n"

  callback null, true

TaggedLogger = (target, tags, debug) ->
  @target = target
  @tags = tags or []
  @logDebug = debug
  return @

TaggedLogger::log = (level, args...) ->
  msg = util.format.apply(null, args)
  @target.log(level, msg, {timestamp: new Date(), tags: @tags})

TaggedLogger::debug = (args...) ->
  level = @target.level
  @target.transports.taggedConsoleLogger.level = "debug" if @logDebug
  if args.length is 1 and args[0]?.stack
    @log "debug", args[0].stack
  else
    @log "debug", args...
  @target.transports.taggedConsoleLogger.level = level
TaggedLogger::info = (args...) -> @log "info", args...
TaggedLogger::warn = (args...) -> @log "warn", args...
TaggedLogger::error = (args...) -> @log "error", args...

TaggedLogger::createSublogger = (tags, debug = false) -> 
  unless Array.isArray(tags)
    tags = [tags]
  newTags = _.uniq(@tags.concat(tags))
  return new TaggedLogger(@target, newTags, debug)


winstonLogger = new (winston.Logger)(
  transports: [
    new TaggedConsoleTarget(
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