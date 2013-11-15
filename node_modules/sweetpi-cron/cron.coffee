# ##Dependencies
# * `node-convice` for config validation.
convict = require "convict"
# * `node-time`: Extend the global Date object to include the `setTimezone` and `getTimezone`.
time = require('time')(Date)
# * `node-cron`: Triggers the time events.
CronJob = require('cron').CronJob
# * `node-chrono` Parses the dates for the `notifyWhen` function.
chrono = require 'chrono-node'  
#  * node.js imports.
spawn = require("child_process").spawn
util = require 'util'
assert = require 'cassert'

module.exports = (env) ->

  # ##The ClockBackend
  class ClockBackend extends env.plugins.Plugin
    server: null
    config: null

    # The `init` function just registers the clock actuator.
    init: (app, @server, @config) =>
      server.registerSensor(new Clock config)

  backend = new ClockBackend

  # ##The Clock-Actuator
  # Provides the time and time events for the rule module.
  class Clock extends env.sensors.Sensor
    config: null
    listener: []

    constructor: (@config) ->
      @id = "clock"
      @name = "clock"

    # Only provides a date object as sensor value
    getSensorValuesNames: ->
      "time"

    getSensorValue: (name)->
      switch name
        when "time"
          now = new Date
          now.setTimezone @config.timezone
          return now
        else throw new Error("Clock sensor doesn't provide sensor value \"#{name}\"")

    canDecide: (predicate) ->
      parsedDate = @parseNaturalTextDate predicate
      return parsedDate?

    # Returns `true` if the given predicate string is considert to be true. For example the 
    # predicate `"Sep 12-13"` is considert to be true if it is the 12th of october, 2013 from 0 to 
    # 23.59 o'clock. If the given predicate is not an valid date string an Error is thrown. 
    isTrue: (id, predicate) ->
      parsedDate = @parseNaturalTextDate predicate
      if parsedDate?
        modifier = @parseNaturalTextModifier predicate
        {second, minute, hour, day, month, dayOfWeek} = @parseDateToCronFormat parsedDate
        now = @getSensorValue "time"
        dateObj = parsedDate.start.date @config.timezone
        return switch modifier
          when 'exact'
            ( second is '*' or now.getSeconds() is dateObj.getSeconds() ) and
            ( minute is '*' or now.getMinutes() is dateObj.getMinutes() ) and
            ( hour is '*' or now.getHours() is dateObj.getHours() ) and
            ( day is '*' or now.getDate() is dateObj.getDate() ) and
            ( month is '*' or now.getMonth() is ddateObj.getMonth() ) and
            ( dayOfWeek is '*' or now.getDay() is dateObj.getDay() )
          when 'after'
            ( second is '*' or now.getSeconds() >= dateObj.getSeconds() ) and
            ( hour is '*' or now.getHours() >= dateObj.getHours() ) and
            ( minute is '*' or now.getMinutes() >= dateObj.getMinutes() ) and
            ( day is '*' or now.getDate() is dateObj.getDate() ) and
            ( month is '*' or now is ddateObj.getMonth() ) and
            ( dayOfWeek is '*' or now.getDay() is dateObj.getDay() )
          when 'before'
            ( second is '*' or now.getSeconds() <= dateObj.getSeconds() ) and
            ( hour is '*' or now.getHours() <= dateObj.getHours() ) and
            ( minute is '*' or now.getMinutes() <= dateObj.getMinutes() ) and
            ( day is '*' or now.getDate() is dateObj.getDate() ) and
            ( month is '*' or now is ddateObj.getMonth() ) and
            ( dayOfWeek is '*' or now.getDay() is dateObj.getDay() )
          else assert false
      else
        throw new Error "Clock sensor can not decide \"#{predicate}\"!"

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      if @listener[id]?
        @listener[id].cronjob.stop()
        delete @listener[id]

    # Registers notification for time events. 
    notifyWhen: (id, predicate, callback) ->
      parsedDate = @parseNaturalTextDate predicate
      if parsedDate?
        modifier = @parseNaturalTextModifier predicate
        {second, minute, hour, day, month, dayOfWeek} = @parseDateToCronFormat parsedDate
        cronFormat = "#{second} #{minute} #{hour} #{day} #{month} #{dayOfWeek}"
        #console.log cronFormat
        job = new CronJob(
          cronTime: cronFormat
          onTick: callback
          start: false
          timezone: @config.timezone
        )
        @listener[id] = 
          id: id
          cronjob: job
          modifier: modifier
        job.start()
      else throw new Error "Clock sensor can not decide \"#{predicate}\"!"

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
      if parsedDates.length is 1
        return parsedDates[0]
      else return null

    parseNaturalTextModifier: (naturalTextDate) ->
      afterRegExp = '.*after\\s.+'
      begoreRegExp = '.*before\\s.+'

      return switch
        when naturalTextDate.match (new RegExp afterRegExp) then 'after'
        when naturalTextDate.match (new RegExp begoreRegExp)
          throw new Error("Sorry before is not supported yet!")#'before'
        else 'exact'


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
      pDate = parsedDate.start

      second = pDate.second
      minute = pDate.minute
      hour = pDate.hour
      #console.log pDate
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

      if pDate.impliedComponents?
        month = if 'month' in pDate.impliedComponents then "*" else pDate.month
        day = if 'day' in pDate.impliedComponents then "*" else pDate.day

      dayOfWeek = if pDate.dayOfWeek? then pDate.dayOfWeek else "*"
      return {
        second: second
        minute: minute
        hour: hour
        day: day
        month: month
        dayOfWeek: dayOfWeek
      }

  return backend