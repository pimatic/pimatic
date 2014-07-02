###
Database
===========
###

assert = require 'cassert'
util = require 'util'
Q = require 'q'
_ = require 'lodash'
S = require 'string'
Knex = require 'knex'
path = require 'path'
M = require './matcher'

module.exports = (env) ->

  dbMapping = {
    logLevelToInt:
      'error': 0
      'warn': 1
      'info': 2
      'debug': 3
    typeMap:
      'number': 'float' 
      'string': 'string'
      'boolean': 'boolean'
      'date': 'timestamp'
    deviceAttributeCache: {}
    typeToAttributeTable: (type) -> "attributeValue#{S(type).capitalize().s}"
  }
  dbMapping.logIntToLevel = _.invert(dbMapping.logLevelToInt)


  ###
  The Database
  ----------------
  ###
  class Database extends require('events').EventEmitter

    constructor: (@framework, @dbSettings) ->

    init: () ->
      connection = _.clone(@dbSettings.connection)
      if @dbSettings.client is 'sqlite3' and connection.filename isnt ':memory:'
        connection.filename = path.resolve(@framework.maindir, '../..', connection.filename)

      pending = Q()

      dbPackageToInstall = @dbSettings.client
      try
        require.resolve(dbPackageToInstall)
      catch e
        unless e.code is 'MODULE_NOT_FOUND' then throw e
        env.logger.info("Installing database package #{dbPackageToInstall}")
        pending = @framework.pluginManager.spawnNpm(['install', dbPackageToInstall])

      pending = pending.then( =>
        @knex = Knex.initialize(
          client: @dbSettings.client
          connection: connection
        )
        @knex.subquery = (query) -> this.raw("(#{query.toString()})")
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
          tableName = dbMapping.typeToAttributeTable(typeName)
          pending.push createTableIfNotExists(tableName, (table) =>
            table.increments('id').primary()
            table.timestamp('time').index() 
            table.integer('deviceAttributeId')
              .references('id')
              .inTable('deviceAttribute')
            table[columnType]('value')
          )
          Q(@knex.raw("""
            CREATE INDEX IF NOT EXISTS
            deviceAttributeIdTime 
            ON #{tableName} (deviceAttributeId, time);
          """)).done()

        # Save log-messages
        @framework.on("messageLogged", ({level, msg, meta}) =>
          @saveMessageEvent(meta.timestamp, level, meta.tags, msg).done()
        )

        # Save device attribute changes
        @framework.on('deviceAttributeChanged', ({device, attributeName, time, value}) =>
          @saveDeviceAttributeEvent(device.id, attributeName, time, value).done()
        )

        @_updateDeviceAttributeExpireInfos()
        @_updateMessageseExpireInfos()

        deleteExpiredEntriesInterval = 30 * 60 * 1000#ms

        return Q.all(pending).then( =>
          deleteExpiredDeviceAttributesCron = ( =>
            env.logger.debug("deleteing expired device attributes")
            return (
              @_deleteExpiredDeviceAttributes()
              .then( onSucces = ->
                Q.delay(deleteExpiredEntriesInterval).then(deleteExpiredDeviceAttributesCron)
              , onError = (error) ->
                env.logger.error(error.message)
                env.logger.debug(error)
                Q.delay(2 * deleteExpiredEntriesInterval).then(deleteExpiredDeviceAttributesCron)
              )
            )
          )
          deleteExpiredDeviceAttributesCron().done()

          deleteExpiredMessagesCron = ( =>
            env.logger.debug("deleteing expired messages")
            return (
              @_deleteExpiredMessages()
              .then( onSucces = ->
                Q.delay(deleteExpiredEntriesInterval).then(deleteExpiredMessagesCron)
              , onError = (error) ->
                env.logger.error(error.message)
                env.logger.debug(error)
                Q.delay(2 * deleteExpiredEntriesInterval).then(deleteExpiredMessagesCron)
              )
            )
          )
          deleteExpiredMessagesCron().done()
        )
      )
      return pending

    getDeviceAttributeLogging: () ->
      return _.clone(@dbSettings.deviceAttributeLogging)

    setDeviceAttributeLogging: (deviceAttributeLogging) ->
      dbSettings.deviceAttributeLogging = deviceAttributeLogging
      @_updateDeviceAttributeExpireInfos()
      @framework.saveConfig()
      return

    _updateDeviceAttributeExpireInfos: ->
      entries = @dbSettings.deviceAttributeLogging
      i = entries.length - 1
      sqlNot = ""
      while i >= 0
        entry = entries[i]
        # Get expire info from entry or create it
        expireInfo = entry.expireInfo
        unless expireInfo?
          expireInfo = {
            expireMs: 0
            whereSQL: ""
          }
          info = {expireInfo}
          info.__proto__ = entry.__proto__
          entry.__proto__ = info
        # Generate sql where to use on deletion
        ownWhere = "1=1"
        if entry.deviceId isnt '*'
          ownWhere += " AND deviceId='#{entry.deviceId}'"
        if entry.attributeName isnt '*'
          ownWhere += " AND attributeName='#{entry.attributeName}'"
        expireInfo.whereSQL = "(#{ownWhere})#{sqlNot}"
        sqlNot = " AND NOT (#{ownWhere})#{sqlNot}"
        # Set expire date
        timeMs = null
        M(entry.time).matchTimeDuration((m, info) => timeMs = info.timeMs)
        unless timeMs? then throw new Error("Can not parse database expire time #{entry.time}")
        expireInfo.expireMs = timeMs  
        i--

    _updateMessageseExpireInfos: ->
      entries = @dbSettings.messageLogging
      i = entries.length - 1
      sqlNot = ""
      while i >= 0
        entry = entries[i]
        # Get expire info from entry or create it
        expireInfo = entry.expireInfo
        unless expireInfo?
          expireInfo = {
            expireMs: 0
            whereSQL: ""
          }
          info = {expireInfo}
          info.__proto__ = entry.__proto__
          entry.__proto__ = info
        # Generate sql where to use on deletion
        ownWhere = "1=1"
        if entry.level isnt '*'
          levelInt = dbMapping.logLevelToInt[entry.level]
          ownWhere += " AND level=#{levelInt}"
        for tag in entry.tags
          ownWhere += " AND tags LIKE \"''#{tag}''%\""
        expireInfo.whereSQL = "(#{ownWhere})#{sqlNot}"
        sqlNot = " AND NOT (#{ownWhere})#{sqlNot}"
        # Set expire date
        timeMs = null
        M(entry.time).matchTimeDuration((m, info) => timeMs = info.timeMs)
        unless timeMs? then throw new Error("Can not parse database expire time #{entry.time}")
        expireInfo.expireMs = timeMs
        i--

    getDeviceAttributeLoggingTime: (deviceId, attributeName) ->
      time = null
      for entry in @dbSettings.deviceAttributeLogging
        if (
          (entry.deviceId is "*" or entry.deviceId is deviceId) and 
          (entry.attributeName is "*" or entry.attributeName is attributeName)
        )
          time = entry.expireInfo.expireMs
      return time

    getMessageLoggingTime: (time, level, tags, text) ->
      time = null
      for entry in @dbSettings.messageLogging
        if (
          (entry.level is "*" or entry.level is level) and 
          (entry.tags.length is 0 or (t for t in entry.tags when t in tags).length > 0)
        )
          time = entry.expireInfo.expireMs
      return time

    _deleteExpiredDeviceAttributes: ->
      awaiting = []
      for entry in  @dbSettings.deviceAttributeLogging
        subquery = @knex('deviceAttribute')
          .select('id')
        subquery.whereRaw(entry.expireInfo.whereSQL)
        subqueryRaw = "deviceAttributeId in (#{subquery.toString()})"
        for type in _.keys(dbMapping.typeMap)
          tableName = dbMapping.typeToAttributeTable(type)
          del = @knex(tableName)
          del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
          del.whereRaw(subqueryRaw)
          del.del()
          awaiting.push del
      return Q.all(awaiting)

    _deleteExpiredMessages: ->
      awaiting = []
      for entry in  @dbSettings.messageLogging
        del = @knex('message')
        del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
        del.whereRaw(entry.expireInfo.whereSQL)
        del.del()
        awaiting.push del
      return Q.all(awaiting)

    saveMessageEvent: (time, level, tags, text) ->
      @emit 'log', {time, level, tags, text}
      #assert typeof time is 'number'
      assert Array.isArray(tags)
      assert typeof level is 'string'
      assert level in _.keys(dbMapping.logLevelToInt) 
      insert = @knex('message').insert(
        time: time
        level: dbMapping.logLevelToInt[level]
        tags: JSON.stringify(tags)
        text: text
      )
      return Q(insert)

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
          m.tags = JSON.parse(m.tags)
          m.level = dbMapping.logIntToLevel[m.level]
        return msgs 
      )

    deleteMessages: (criteria = {}) ->
      query = @knex('message')
      @_buildMessageWhere(query, criteria)
      return Q((query).del()) 


    queryDeviceAttributeEvents: (queryCriteria = {}) ->
      {
        deviceId, 
        attributeName, 
        after, 
        before, 
        order, 
        orderDirection, 
        offset, 
        limit
      } = queryCriteria 
      unless order?
        order = "time"
        orderDirection = "desc"

      buildQueryForType = (tableName, query) =>
        query.select(
          "#{tableName}.id AS id", 
          'deviceAttribute.deviceId', 
          'deviceAttribute.attributeName', 
          'deviceAttribute.type',
          'time', 
          'value'
        ).from(tableName)
        if after?
          query.where('time', '>=', after)
        if before?
          query.where('time', '<=', before)
        query.join('deviceAttribute', 
          "#{tableName}.deviceAttributeId", '=', 'deviceAttribute.id',
        )
        if deviceId?
          query.where('deviceId', deviceId)
        if attributeName?
          query.where('attributeName', attributeName)

      query = null
      for type in _.keys(dbMapping.typeMap)
        tableName = dbMapping.typeToAttributeTable(type)
        unless query?
          query = @knex(tableName)
          buildQueryForType(tableName, query)
        else
          query.unionAll( -> buildQueryForType(tableName, this) )
      query = @knex()
        .from(@knex.subquery(query))
        .select('*')
        .orderBy(order, orderDirection)
      if offset? then query.offset(offset)
      if limit? then query.limit(limit)
      return Q(query).then( (result) ->
        for r in result
          if r.type is "boolean" then r.value = !!r.value
        return result
      )

    querySingleDeviceAttributeEvents: (deviceId, attributeName, queryCriteria = {}) ->
      {
        after, 
        before, 
        order, 
        orderDirection, 
        offset, 
        limit,
        groupByTime
      } = queryCriteria 
      unless order?
        order = "time"
        orderDirection = "asc"
      return @_getDeviceAttributeInfo(deviceId, attributeName).then( (info) =>
        query = @knex(dbMapping.typeToAttributeTable(info.type))
        unless groupByTime?
          query.select('time', 'value')
        else
          query.select(@knex.raw('MIN(time) AS time'), @knex.raw('AVG(value) AS value'))
        query.where('deviceAttributeId', info.id)
        if after?
          query.where('time', '>=', parseFloat(after))
        if before?
          query.where('time', '<=', parseFloat(before))
        if order?
          query.orderBy(order, orderDirection)
        if groupByTime?
          groupByTime = parseFloat(groupByTime);
          query.groupByRaw("time/#{groupByTime}")
        if offset? then query.offset(offset)
        if limit? then query.limit(limit)
        time = new Date().getTime()
        env.logger.debug "query:", query.toString() 
        return Q(query).then( (result) =>
          timeDiff = new Date().getTime()-time
          env.logger.debug "quering #{result.length} events took #{timeDiff}ms."
          return result
        )
      )

    saveDeviceAttributeEvent: (deviceId, attributeName, time, value) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      @emit 'device-attribute-save', {deviceId, attributeName, time, value}

      return @_getDeviceAttributeInfo(deviceId, attributeName).then( (info) =>
        tableName = dbMapping.typeToAttributeTable(info.type)
        insert = @knex(tableName).insert(
          time: time
          deviceAttributeId: info.id
          value: value
        )
        return Q(insert)
      )

    _getDeviceAttributeInfo: (deviceId, attributeName) ->
      fullQualifier = "#{deviceId}.#{attributeName}"
      info = dbMapping.deviceAttributeCache[fullQualifier]
      return (
        if info? then Q(info)
        else @_insertDeviceAttribute(deviceId, attributeName)
      )


    _insertDeviceAttribute: (deviceId, attributeName) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      device = @framework.getDeviceById(deviceId)
      unless device? then throw new Error("#{deviceId} not found.")
      attribute = device.attributes[attributeName]
      unless attribute? then throw new Error("#{deviceId} has no attribute #{attributeName}.")

      info = {
        id: null
        type: attribute.type
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


  return exports = { Database }