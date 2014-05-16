###
Eventlog
===========
###

assert = require 'cassert'
util = require 'util'
Q = require 'q'
_ = require 'lodash'
S = require 'string'
Knex = require 'knex'

module.exports = (env) ->

  dbMapping = {
    logLevelToInt:
      'error': 0
      'warning': 1
      'info': 2
      'debug': 3
    typeMap:
      'Number': 'float' 
      'String': 'string'
      'Boolean': 'boolean'
      'Date': 'timestamp'
    deviceAttributeCache: {}
  }
  dbMapping.logIntToLevel = _.invert(dbMapping.logLevelToInt)


  ###
  The Eventlog
  ----------------
  ###
  class Eventlog extends require('events').EventEmitter

    constructor: (@framework) ->
      @_setup()

    _setup: ->
      @knex = Knex.initialize(
        client: 'sqlite3'
        connection: {
          filename: "./mydb.sqlite"
        }
      )

      createTableIfNotExists = (tableName, cb) =>
        @knex.schema.hasTable(tableName).then( (exists) =>
          if not exists        
            return @knex.schema.createTable(tableName, cb).then(( =>
              env.logger.info("#{tableName} table created!")
            ), (error) =>
              env.logger.error(error) 
            )
        )

      pending = []

      pending.push createTableIfNotExists('message', (table) =>
        table.increments('id').primary()
        table.timestamp('time')
        table.integer('level')
        table.text('text')
      )
      pending.push createTableIfNotExists('deviceAttribute', (table) =>
        table.increments('id').primary()
        table.string('deviceId')
        table.string('attributeName')
        table.string('type')
      )

      for typeName, columnType of dbMapping.typeMap
        pending.push createTableIfNotExists("attributeValue#{typeName}", (table) =>
          table.increments('id').primary()
          table.timestamp('time').index() 
          table.integer('deviceAttributeId')
            .references('id')
            .inTable('deviceAttribute')
          table[columnType]('value')
        )

      Q.all(pending).then( =>

        time = (new Date()).getTime()
        Q.all(
          Q(@saveMessageEvent(new Date(), 'info', 'test')).done() for i in [0..100]
        ).then( =>
          console.log "insert:", (new Date()).getTime() - time
        ).then( =>
          time = (new Date()).getTime()
          @queryMessages().then( (result) =>
            console.log "query:", (new Date()).getTime() - time
            console.log result
          )
        ).done()


        # console.log "ready"
        # time = (new Date()).getTime()
        # Q(@saveMessageEvent(new Date(), 'info', 'test')).done()
        # @saveDeviceAttributeEvent('my-phone', 'presence', time, true).then( =>
        #   console.log dbMapping.deviceAttributeCache
        # )
        # @queryMessages().then( (result) =>
        #   console.log result
        # )

        # @queryDeviceAttributeValues({deviceId: 'my-phone', attributeName: 'presence'}).then( (result) =>
        #   console.log result
        # )

        # @knex('message').select().then( (result) =>
        #   console.log result
        # )
      ).done()


    saveMessageEvent: (time, level, text) ->
      #assert typeof time is 'number'
      assert typeof level is 'string'
      assert level in _.keys(dbMapping.logLevelToInt)

      return @knex('message').insert(
        time: time
        level: dbMapping.logLevelToInt[level]
        text: text
      )

    queryMessages: ({level, levelOp, after, before} = {}) ->
      query = @knex('message').select('time', 'level', 'text')
      if level?
        unless levelOp then levelOp = '='
        query.where('level', levelOp, dbMapping.logLevelToInt['level'])
      if after?
        query.where('time', '>=', after)
      if before?
        query.where('time', '<=', before)
      return Q(query).then( (msgs) =>
        for m in msgs
          m.level = dbMapping.logIntToLevel[m.level]
        return msgs 
      )

    queryDeviceAttributeValues: ({deviceId, attributeName, after, before} = {}) ->
      
      buildQueryForType = (tableName, query) =>
        query.select("#{tableName}.id", 'time', 'value').from(tableName)
        if after?
          query.where('time', '>=', after)
        if before?
          query.where('time', '<=', before)
        if deviceId? or attributeName?
          query.join('deviceAttribute', 
            "#{tableName}.deviceAttributeId", '=', 'deviceAttribute.id',
          )
          if deviceId?
            query.where('deviceId', deviceId)
          if attributeName?
            query.where('attributeName', attributeName)


      query = null;
      for type in _.keys(dbMapping.typeMap)
        tableName = "attributeValue#{type}"
        unless query?
          query = @knex(tableName)
          buildQueryForType(tableName, query)
        else
          query.unionAll( -> buildQueryForType(tableName, this) )
      #console.log query.toString()
      return Q(query)


    saveDeviceAttributeEvent: (deviceId, attributeName, time, value) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      return @_getDeviceAttributeInfo(deviceId, attributeName).then( (info) =>
        tableName = "attributeValue#{info.type}"
        return @knex(tableName).insert(
          time: time
          deviceAttributeId: info.id
          value: value
        )
      )

    _getDeviceAttributeInfo: (deviceId, attributeName) ->
      fullQualifier = "#{deviceId}.#{attributeName}"
      info = dbMapping.deviceAttributeCache[fullQualifier];
      return (
        if info? then Q(info)
        else @_insertDeviceAttribue(deviceId, attributeName)
      )


    _insertDeviceAttribue: (deviceId, attributeName) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      device = @framework.getDeviceById(deviceId)
      unless device? then throw new Error("#{deviceId} not found.")
      attribute = device.attributes[attributeName]
      unless attribute? then throw new Error("#{deviceId} has no attribute #{attributeName}.")

      info = {
        id: null
        type: attribute.type.name
      }

      ###
        Don't create a new entry for the device if an entry with the attributeName and deviceId
        already exists.
      ###
      return @knex.raw("""
        INSERT INTO deviceAttribute(deviceId, attributeName, type)
        SELECT
          '#{deviceId}' AS deviceId,
          '#{attributeName}' AS attributeName,
          '#{info.type}' as type
        WHERE 0 = (
          SELECT COUNT(*)
          FROM deviceAttribute
          WHERE deviceId = '#{deviceId}' and attributeName = '#{attributeName}'
        );
        """).then( => 
        @knex('deviceAttribute').select('id').where(
          deviceId: deviceId
          attributeName: attributeName
        ).then( ([result]) =>
          info.id = result.id
          assert info.id? and typeof info.id is "number"
          fullQualifier = "#{deviceId}.#{attributeName}"
          return (dbMapping.deviceAttributeCache[fullQualifier] = info)
        )
      )


  return exports = { Eventlog  }