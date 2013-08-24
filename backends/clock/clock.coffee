# #The clock backend
# Provides a clock module, so actions can be triggert at a specific time
# ##Provided predicates
# For example:
# 
# * the condition `"Sep 12-13"` is true on the 12th of october, 2013 from 0 to 
#   23.59 o'clock 
# * the condition `"friday 17:00"` is true every friday at 5pm.

# ##Dependencies
# * `node-convice` for config validation.
convict = require "convict"
# * `node-time`: Extend the global Date object to include the `setTimezone` and `getTimezone`.
time = require('time')(Date);
# * `node-cron`: Triggers the time events.
CronJob = require('cron').CronJob;
# * `node-chrono` Parses the dates for the `notifyWhen` function.
chrono = require 'chrono-node'  
#  * node.js imports.
spawn = require("child_process").spawn
util = require 'util'
# * sweetpi imports.
modules = require '../../lib/modules'
sensors = require "../../lib/sensors"

# ##The ClockBackend
class ClockBackend extends modules.Backend
  server: null
  config: null

  # The `init` function just registers the clock actuator.
  init: (@server, @config) =>
    server.registerSensor(new Clock config)

backend = new ClockBackend

# ##The Clock-Actuator
# Provides the time and time events for the rule module.
class Clock extends sensors.Sensor
  config: null
  cronJobs: []

  constructor: (@config) ->
    @id = "clock"
    @name = "clock"

  # Only provides a date object as sensor value
  getSensorValuesNames: ->
    "time"

  getSensorValue: (name)->
    switch name
      when "time"
        now = new Date();
        now.setTimezone config.timezone
        return now
      else throw new Error("Clock sensor doesn't provide sensor value \"#{name}\"")

  # Returns `true` if the given predicate string is considert to be true. For example the predicate
  # `"Sep 12-13"` is considert to be true if it is the 12th of october, 2013 from 0 to 
  # 23.59 o'clock. If the given predicate is not an valid date string an Error is thrown. 
  isTrue: (id, predicate) ->
    parsedDate = @parseNaturalTextDate predicate
    if parsedDate?
      {second, minute, hour, day, month, dayOfWeek} = @parseDateToCronFormat parsedDate
      now = @getSensorValue "time"
      dateObj = date.start.date(config.timezone)
      switch
        when second isnt '*' and now.getSeconds() isnt dateObj.getSeconds() then return false
        when minute isnt '*' and now.getMinutes() isnt dateObj.getMinutes() then return false
        when hour isnt '*' and now.getHours() isnt dateObj.getHours() then return false
        when day isnt '*' and now.getDate() isnt dateObj.getDate() then return false
        when month isnt '*' and now.getMonth() isnt ddateObj.getMonth() then return false
        when dayOfWeek isnt '*' and now.getDay() isnt dateObj.getDay() then return false
        else return true
    else
      throw new Error "Clock seonsor can not decide \"predicate\"!"

  # Removes the notification for an with `notifyWhen` registered predicate. 
  cancelNotify: (id) ->
    if @cronJobs[id]?
      @cronJobs[id].stop()
      delete @cronJobs[id]

  # Registers notification for time events. 
  notifyWhen: (id, predicate, callback) ->
    parsedDate = @parseNaturalTextDate predicate
    if parsedDate?

      {second, minute, hour, day, month, dayOfWeek} = @parseDateToCronFormat parsedDate
      cronFormat = "#{second} #{minute} #{hour} #{day} #{month} #{dayOfWeek}"
      #console.log cronFormat
      job = new CronJob(
        cronTime: cronFormat
        onTick: callback
        start: false
        timezone: config.timezone
      )
      @cronJobs[id] = job;
      job.start()
      return true
    return false

  # Take a date as string in natural language and parse it with 
  # [chrono-node](https://github.com/berryboy/chrono).
  # For example transforms:
  # `"Sep 12-13"`
  # to:
  # 
  #     { start: 
  #       { year: 2013,
  #         month: 8,
  #         day: 12,
  #         isCertain: [Function],
  #         impliedComponents: [Object],
  #         date: [Function] },
  #      startDate: Thu Sep 12 2013 12:00:00 GMT+0900 (JST),
  #      end: 
  #       { year: 2013,
  #         month: 8,
  #         day: 13,
  #         impliedComponents: [Object],
  #         isCertain: [Function],
  #         date: [Function] },
  #      endDate: Fri Sep 13 2013 12:00:00 GMT+0900 (JST),
  #      referenceDate: Sat Aug 17 2013 17:54:57 GMT+0900 (JST),
  #      index: 0,
  #      text: 'Sep 12-13',
  #      concordance: 'Sep 12-13' }
  parseNaturalTextDate: (naturalTextDate)->
    parsedDates = chrono.parse naturalTextDate 
    if parsedDates.length != 1
      return parsedDates[0]
    else return null

  # Convert a parsedDate to a cronjob-syntax like object. The parsedDate must be parsed from 
  # [chrono-node](https://github.com/berryboy/chrono). For Exampe converts the parsedDate of
  # `"12:00"` to:
  # 
  #     {
  #       second: 0
  #       minute: 0
  #       hour: 12
  #       day: "*"
  #       month: "*"
  #       dayOfWeek: "*"
  #     }
  #  
  # or `"Monday"` gets:
  # 
  #     {
  #       second: 0
  #       minute: 0
  #       hour: 0
  #       day: "*"
  #       month: "*"
  #       dayOfWeek: 1
  #     }
  parseDateToCronFormat: (parsedDate)->
    second = parsedDate.start.second
    minute = parsedDate.start.minute
    hour = parsedDate.start.hour

    if not second? and not minute? and not hour
      second = 0
      minute = 0
      hour = 0
    else 
      if not second?
        second = "*"
      if not minute?
        minute = "*"
      if not hour?
        hour = "*"

    if parsedDate.start.impliedComponents
      moarsednth = if 'month' in pDate.start.impliedComponents then "*" else pDate.start.month
      daarsedy = if 'day' in pDate.start.impliedComponents then "*" else pDate.start.day
    else 
      month = parsedDate.start.month
      day = parsedDate.start.day
    dayOfWearsedek = if pDate.start.dayOfWeek? then pDate.start.dayOfWeek else "*"
    return {
      second: second
      minute: minute
      hour: hour
      day: day
      month: month
      dayOfWeek: dayOfWeek
    }


# Export the Backendmodule.
module.exports = backend