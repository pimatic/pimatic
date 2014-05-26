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
path = require 'path'

module.exports = (env) ->

  messageCriteria = {
    criteria:
      type: Object
      optional: yes
      properties:
        level:
          type: 'any'
          optional: yes
        levelOp:
          type: String
          optional: yes
        after:
          type: Date
          optional: yes
        before:
          type: Date
          optional: yes
  }

  api = {
    actions:
      queryMessages:
        desciption: "list log messages"
        params: messageCriteria
        result:
          messages:
            type: Array
      deleteMessages:
        description: "delets messages older than the given date"
        params: messageCriteria
      setDeviceAttributeLogging:
        description: "enable or disable logging for an device attribute"
        params:
          deviceId:
            type: String
          attributeName:
            type: String
          enable:
            type: Boolean
      queryMessagesTags:
        description: "lists all tags from the matching messages"
        params: messageCriteria
        result:
          tags:
            type: Array
      queryMessagesCount:
        description: "count of all matches matching the criteria"
        params: messageCriteria
        result:
          count:
            type: Number
  }





  dbMapping = {
    logLevelToInt:
      'error': 0
      'warn': 1
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

    constructor: (@framework, @dbSettings) ->

    init: () ->
      connection = _.clone(@dbSettings.connection)
      if @dbSettings.client is 'sqlite3' and connection.filename isnt ':memory:'
        connection.filename = path.resolve(@framework.maindir, '../..', connection.filename)

      @knex = Knex.initialize(
        client: @dbSettings.client
        connection: connection
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
        table.text('tags')
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

      # wiring up the logger
      env.logger.winston.on "logged", (level, msg, meta) =>
        @saveMessageEvent(meta.timestamp, level, meta.tags, msg).done()

      # wiring up device attributes
      @framework.on('device', (device) =>
        for name, attr of device.attributes
          do (name, attr) =>
            device.on(name, onChange = (value) =>
              fullQualifier = "#{device.id}.#{name}"
              if fullQualifier in @dbSettings.deviceAttributeLogging
                now = new Date()
                @saveDeviceAttributeEvent(device.id, name, now, value).done()
            )
      )

      return Q.all(pending)

    setDeviceAttributeLogging: (deviceId, attributeName, enable) ->
      fullQualifier = "#{deviceId}.#{attributeName}"
      if enable
        if fullQualifier in @dbSettings.deviceAttributeLogging then return
        @dbSettings.deviceAttributeLogging.push fullQualifier
      else
        @dbSettings.deviceAttributeLogging = _.filter(
          @dbSettings.deviceAttributeLogging, 
          (fq) => fq isnt fullQualifier
        )
      @framework.saveConfig()
      return


    saveMessageEvent: (time, level, tags, text) ->
      @emit 'log', {time, level, tags, text}
      #assert typeof time is 'number'
      assert Array.isArray(tags)
      assert typeof level is 'string'
      assert level in _.keys(dbMapping.logLevelToInt) 
      return Q(@knex('message').insert(
        time: time
        level: dbMapping.logLevelToInt[level]
        tags: JSON.stringify(tags)
        text: text
      ))

    _buildMessageWhere: (query, {level, levelOp, after, before, tags, offset, limit}) ->
      if level?
        unless levelOp then levelOp = '='
        if Array.isArray(level)
          level = _.map(level, (l) => dbMapping.logLevelToInt[l])
          query.whereIn('level', level)
        else
          query.where('level', levelOp, dbMapping.logLevelToInt[level])
      if after?
        query.where('time', '>=', after)
      if before?
        query.where('time', '<=', before)
      if tags?
        unless Array.isArray tags then tags = [tags]
        for tag in tags
          query.where('tags', 'like', "%\"#{tag}\"%")
      query.orderBy('time', 'desc')
      if offset?
        query.offset(offset)
      if limit?
        query.limit(limit)

    queryMessagesCount: (criteria = {})->
      query = @knex('message').count('*')
      @_buildMessageWhere(query, criteria)
      return Q(query).then( (result) => result[0]["count(*)"] )

    queryMessagesTags: (criteria = {})->
      query = @knex('message').distinct('tags').select()
      @_buildMessageWhere(query, criteria)
      return Q(query).then( (tags) =>
        _(tags).map((r)=>JSON.parse(r.tags)).flatten().uniq().valueOf()
      )


    queryMessages: (criteria = {}) ->
      query = @knex('message').select('time', 'level', 'tags', 'text')
      @_buildMessageWhere(query, criteria)
      return Q(query).then( (msgs) =>
        for m in msgs
          m.level = dbMapping.logIntToLevel[m.level]
          m.tags = JSON.parse(m.tags)
        return msgs 
      )

    deleteMessages: (criteria = {}) ->
      query = @knex('message')
      @_buildMessageWhere(query, criteria)
      return Q((query).del()) 


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

      query = null
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

      @emit 'device-attribute', {deviceId, attributeName, time, value}

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
      info = dbMapping.deviceAttributeCache[fullQualifier]
      return (
        if info? then Q(info)
        else @_insertDeviceAttribue(deviceId, attributeName)
      )


    _insertDeviceAttribue: (deviceId, attributeName) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      console.log "insert d a"
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


  return exports = { Eventlog, api }