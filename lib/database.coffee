###
Database
===========
###

assert = require 'cassert'
util = require 'util'
Promise = require 'bluebird'
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
      'number': "attributeValueNumber"
      'string': "attributeValueString"
      'boolean': "attributeValueNumber"
      'date': "attributeValueNumber"
    attributeValueTables:
      "attributeValueNumber": {
        valueColumnType: "float"
      }
      "attributeValueString": {
        valueColumnType: "string"
      }

    deviceAttributeCache: {}
    typeToAttributeTable: (type) -> @typeMap[type]
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

      pending = Promise.resolve()

      dbPackageToInstall = @dbSettings.client
      try
        require.resolve(dbPackageToInstall)
      catch e
        unless e.code is 'MODULE_NOT_FOUND' then throw e
        env.logger.info(
          "Installing database package #{dbPackageToInstall}, this can take some minutes"
        )
        pending = @framework.pluginManager.spawnNpm(['install', dbPackageToInstall])

      return pending.then( =>
        @knex = Knex.initialize(
          client: @dbSettings.client
          connection: connection
        )
        @knex.subquery = (query) -> this.raw("(#{query.toString()})")
        if @dbSettings.client is "sqlite3"
          return @knex.raw("PRAGMA auto_vacuum=FULL;")
      ).then( =>         
        @_createTables()
      ).then( =>     
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

        setInterval( ( =>
          env.logger.debug("deleteing expired device attributes") if @dbSettings.debug
          @_deleteExpiredDeviceAttributes().catch( (error) =>
            env.logger.error(error.message)
            env.logger.debug(error.stack)
          ).done()
        ), deleteExpiredEntriesInterval)

        setInterval( ( =>
          env.logger.debug("deleteing expired messages") if @dbSettings.debug
          @_deleteExpiredMessages().catch( (error) =>
            env.logger.error(error.message)
            env.logger.debug(error.stack)
          ).done()
        ), deleteExpiredEntriesInterval)

        return
      )

      

    _createTables: ->
      pending = []

      createTableIfNotExists = ( (tableName, cb) =>
        @knex.schema.hasTable(tableName).then( (exists) =>
          if not exists        
            return @knex.schema.createTable(tableName, cb).then(( =>
              env.logger.info("#{tableName} table created!")
            ), (error) =>
              env.logger.error(error)
              env.logger.debug(error.stack)
            )
          else return
        )
      )

      pending.push createTableIfNotExists('message', (table) =>
        table.increments('id').primary()
        table.timestamp('time').index()
        table.integer('level')
        table.text('tags')
        table.text('text')
      )
      pending.push createTableIfNotExists('deviceAttribute', (table) =>
        table.increments('id').primary()
        table.string('deviceId')
        table.string('attributeName')
        table.string('type')
        table.timestamp('lastUpdate').nullable()
        table.string('lastValue').nullable()
      )

      # add to old deviceAttribute table 
      pending.push @knex.schema.table('deviceAttribute', (table) =>
        table.timestamp('lastUpdate').nullable()
        table.string('lastValue').nullable()
      ).catch( (error) -> 
        if error.errno is 1 then return #ignore
        throw error
      )

      for tableName, tableInfo of dbMapping.attributeValueTables
        pending.push createTableIfNotExists(tableName, (table) =>
          table.increments('id').primary()
          table.timestamp('time').index() 
          table.integer('deviceAttributeId')
            .references('id')
            .inTable('deviceAttribute')
          table[tableInfo.valueColumnType]('value')
        ).then( =>
          return @knex.raw("""
            CREATE INDEX IF NOT EXISTS
            deviceAttributeIdTime 
            ON #{tableName} (deviceAttributeId, time);
          """)
        )

      return Promise.all(pending).then( =>
        return @knex.raw("""
          CREATE INDEX IF NOT EXISTS
          deviceAttributeDeviceIdAttributeName ON 
          deviceAttribute(deviceId, attributeName);
          CREATE INDEX IF NOT EXISTS
          deviceAttributeDeviceId ON 
          deviceAttribute(deviceId);
          CREATE INDEX IF NOT EXISTS
          deviceAttributeAttributeName ON 
          deviceAttribute(attributeName);
        """)
      )

    getDeviceAttributeLogging: () ->
      return _.clone(@dbSettings.deviceAttributeLogging)

    setDeviceAttributeLogging: (deviceAttributeLogging) ->
      dbSettings.deviceAttributeLogging = deviceAttributeLogging
      @_updateDeviceAttributeExpireInfos()
      @framework.saveConfig()
      return

    _updateDeviceAttributeExpireInfos: ->
      for info in dbMapping.deviceAttributeCache
        info.expireMs = null
        info.intervalMs = null
      entries = @dbSettings.deviceAttributeLogging
      i = entries.length - 1
      sqlNot = ""
      possibleTypes = ["number", "string", "boolean", "date", "*"]
      while i >= 0
        entry = entries[i]
        #legazy support
        if entry.time?
          entry.expire = entry.time
          delete entry.time
        unless entry.type?
          entry.type = "*"

        unless entry.type in possibleTypes
          throw new Error("type option in database config must be one of #{possibleTypes}")

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
        if entry.type isnt '*'
          ownWhere += " AND type='#{entry.type}'"

        expireInfo.whereSQL = "(#{ownWhere})#{sqlNot}"
        sqlNot = " AND NOT (#{ownWhere})#{sqlNot}"
        # Set expire date
        expireInfo.expireMs = @_parseTime(entry.expire) if entry.expire?
        expireInfo.interval = @_parseTime(entry.interval) if entry.interval?
        i--

    _parseTime: (time) ->
      if time is "0" then return 0
      else
        timeMs = null
        M(time).matchTimeDuration((m, info) => timeMs = info.timeMs)
        unless timeMs?
          throw new Error("Can not parse time in database config: #{time}")
        return timeMs

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
        expireInfo.expireMs = @_parseTime(entry.expire) if entry.expire?
        i--


     getDeviceAttributeLoggingTime: (deviceId, attributeName, type) ->
      expireMs = 0
      expire = "0"
      intervalMs = 0
      interval = "0"
      for entry in @dbSettings.deviceAttributeLogging
        matches = (
          (entry.deviceId is '*' or entry.deviceId is deviceId) and
          (entry.attributeName is '*' or entry.attributeName is attributeName) and
          (entry.type is '*' or entry.type is type)
        )
        if matches
          if entry.expire?
            expireMs = entry.expireInfo.expireMs
            expire = entry.expire
          if entry.interval?
            intervalMs = entry.expireInfo.interval
            interval = entry.interval
      return {expireMs, intervalMs, expire, interval}

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
        for tableName in _.keys(dbMapping.attributeValueTables)
          del = @knex(tableName)
          del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
          del.whereRaw(subqueryRaw)
          del.del()
          awaiting.push del
      return Promise.all(awaiting)

    _deleteExpiredMessages: ->
      awaiting = []
      for entry in  @dbSettings.messageLogging
        del = @knex('message')
        del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
        del.whereRaw(entry.expireInfo.whereSQL)
        del.del()
        awaiting.push del
      return Promise.all(awaiting)

    saveMessageEvent: (time, level, tags, text) ->
      @emit 'log', {time, level, tags, text}
      #assert typeof time is 'number'
      assert Array.isArray(tags)
      assert typeof level is 'string'
      assert level in _.keys(dbMapping.logLevelToInt) 

      expireMs = @getMessageLoggingTime(time, level, tags, text)
      if expireMs is 0
        return Promise.resolve()

      insert = @knex('message').insert(
        time: time
        level: dbMapping.logLevelToInt[level]
        tags: JSON.stringify(tags)
        text: text
      )
      return Promise.resolve(insert)

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
      return Promise.resolve(query).then( (result) => result[0]["count(*)"] )

    queryMessagesTags: (criteria = {})->
      query = @knex('message').distinct('tags').select()
      @_buildMessageWhere(query, criteria)
      return Promise.resolve(query).then( (tags) =>
        _(tags).map((r)=>JSON.parse(r.tags)).flatten().uniq().valueOf()
      )

    queryMessages: (criteria = {}) ->
      query = @knex('message').select('time', 'level', 'tags', 'text')
      @_buildMessageWhere(query, criteria)
      return Promise.resolve(query).then( (msgs) =>
        for m in msgs
          m.tags = JSON.parse(m.tags)
          m.level = dbMapping.logIntToLevel[m.level]
        return msgs 
      )

    deleteMessages: (criteria = {}) ->
      query = @knex('message')
      @_buildMessageWhere(query, criteria)
      return Promise.resolve((query).del()) 

    _buildQueryDeviceAttributeEvents: (queryCriteria = {}) ->
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
          'deviceAttribute.deviceId AS deviceId', 
          'deviceAttribute.attributeName AS attributeName', 
          'deviceAttribute.type AS type',
          'time AS time', 
          'value AS value'
        ).from(tableName).join('deviceAttribute', 
          "#{tableName}.deviceAttributeId", '=', 'deviceAttribute.id',
        )
        if deviceId?
          query.where('deviceId', deviceId)
        if attributeName?
          query.where('attributeName', attributeName)

      query = null
      for tableName in _.keys(dbMapping.attributeValueTables)
        unless query?
          query = @knex(tableName)
          buildQueryForType(tableName, query)
        else
          query.unionAll( -> buildQueryForType(tableName, this) )

      if after?
        query.where('time', '>=', parseFloat(after))
      if before?
        query.where('time', '<=', parseFloat(before))
      query.orderBy(order, orderDirection)
      if offset? then query.offset(offset)
      if limit? then query.limit(limit)
      return query

    queryDeviceAttributeEvents: (queryCriteria) ->
      query = @_buildQueryDeviceAttributeEvents(queryCriteria)
      env.logger.debug("query:", query.toString()) if @dbSettings.debug
      time = new Date().getTime()
      return Promise.resolve(query).then( (result) =>
        timeDiff = new Date().getTime()-time
        if @dbSettings.debug
          env.logger.debug("quering #{result.length} events took #{timeDiff}ms.")
        for r in result
          if r.type is "boolean"
            # convert numeric or string value from db to boolean
            r.value = not (r.value is "0" or r.value is 0)
        return result
      )

    queryDeviceAttributeEventsCount: () ->
      pending = []
      for tableName in _.keys(dbMapping.attributeValueTables)
        pending.push @knex(tableName).count('* AS count')
      return Promise.all(pending).then( (counts) =>
        count = 0
        for c in counts
          count += c[0].count
        return count
      )

    queryDeviceAttributeEventsDevices: () ->
      return @knex('deviceAttribute').select(
        'id',
        'deviceId', 
        'attributeName', 
        'type'
      )

    queryDeviceAttributeEventsInfo: () ->
      return @knex('deviceAttribute').select(
        'id',
        'deviceId', 
        'attributeName', 
        'type'
      ).then( (results) =>
        for result in results
          info = @getDeviceAttributeLoggingTime(result.deviceId, result.attributeName, result.type)
          result.interval = info.interval
          result.expire = info.expire
        return results
      ).map( (result) =>
        @knex(dbMapping.typeMap[result.type])
          .count('*')
          .where('deviceAttributeId', result.id)
          .then( (count) => result.count = count[0]["count(*)"]; return result )
      )

    runVacuum: -> @knex.raw('VACUUM;')

    checkDatabase: () ->
      @knex('deviceAttribute').select(
        'id'
        'deviceId', 
        'attributeName', 
        'type',
        'count(*) '
      ).then( (results) =>
        problems = []
        for result in results
          device = @framework.deviceManager.getDeviceById(result.deviceId)
          unless device?
            problems.push {
              id: result.id
              deviceId: result.deviceId
              attribute: result.attributeName
              description: "No device with the id \"#{result.deviceId}\" found."
              action: "delete"
            }
          else
            unless device.hasAttribute(result.attributeName)
              problems.push {
                id: result.id
                deviceId: result.deviceId
                attribute: result.attributeName
                description: "Device \"#{result.deviceId}\" has no attribute with the name " +
                        "\"#{result.attributeName}\" found."
                action: "delete"
              }
            else
              attribute = device.attributes[result.attributeName]
              if attribute.type isnt result.type
                problems.push {
                  id: result.id
                  deviceId: result.deviceId
                  attribute: result.attributeName
                  description: "Attribute \"#{result.attributeName}\" of  \"#{result.deviceId}\" " +
                           "has the wrong type"
                  action: "delete"
                }
        return problems
      )

    deleteDeviceAttribute: (id) ->
      awaiting = []
      awaiting.push @knex('deviceAttribute').where('id', id).del()

      for tableName, tableInfo of dbMapping.attributeValueTables
        awaiting.push @knex(tableName).where('deviceAttributeId', id).del()
      return Promise.all(awaiting)

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
          groupByTime = parseFloat(groupByTime)
          query.groupByRaw("time/#{groupByTime}")
        if offset? then query.offset(offset)
        if limit? then query.limit(limit)
        env.logger.debug("query:", query.toString()) if @dbSettings.debug
        time = new Date().getTime()
        return Promise.resolve(query).then( (result) =>
          timeDiff = new Date().getTime()-time
          if @dbSettings.debug
            env.logger.debug("quering #{result.length} events took #{timeDiff}ms.")
          return result
        )
      )

    saveDeviceAttributeEvent: (deviceId, attributeName, time, value) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      @emit 'device-attribute-save', {deviceId, attributeName, time, value}

      return @_getDeviceAttributeInfo(deviceId, attributeName).then( (info) =>
        # insert into value table
        tableName = dbMapping.typeToAttributeTable(info.type)
        timestamp = time.getTime()
        if info.expireMs is 0
          # value expires immediatly
          doInsert = false
        else
          if info.intervalMs is 0 or timestamp - info.lastInsertTime > info.intervalMs 
            doInsert = true
          else
            doInsert = false

        if doInsert
          info.lastInsertTime = timestamp
          insert1 = @knex(tableName).insert(
            time: time
            deviceAttributeId: info.id
            value: value
          )
        else
          insert1 = Promise.resolve()
        # and update lastValue in attributeInfo
        insert2 = @knex('deviceAttribute')
          .where(
            id: info.id
          )
          .update(
            lastUpdate: time
            lastValue: value
          )
        return Promise.all([insert1, insert2])
      )

    _getDeviceAttributeInfo: (deviceId, attributeName) ->
      fullQualifier = "#{deviceId}.#{attributeName}"
      info = dbMapping.deviceAttributeCache[fullQualifier]
      return (
        if info? 
          unless info.expireMs?
            expireInfo = @getDeviceAttributeLoggingTime(deviceId, attributeName, info.type)
            info.expireMs = expireInfo.expireMs
            info.intervalMs = expireInfo.intervalMs
            info.lastInsertTime = 0
          Promise.resolve(info)
        else @_insertDeviceAttribute(deviceId, attributeName)
      )


    getLastDeviceState: (deviceId) ->
      if @_lastDevicesStateCache?
        return @_lastDevicesStateCache.then( (devices) -> devices[deviceId] )
      
      # query all devices for performance reason and cache the result
      @_lastDevicesStateCache = @knex('deviceAttribute').select(
        'deviceId', 'attributeName', 'type', 'lastUpdate', 'lastValue'
      ).then( (result) =>
        #group by device
        devices = {}
        convertValue = (value, type) ->
          unless value? then return null
          return (
            switch type
              when 'number' then parseFloat(value)
              when 'boolean' then (value is '1')
              else value
          )
        for r in result
          d = devices[r.deviceId]
          unless d? then d = devices[r.deviceId] = {}
          d[r.attributeName] = {
            time: r.lastUpdate
            value: convertValue(r.lastValue, r.type)
          }
        # Clear cache after one minute
        clearTimeout(@_lastDevicesStateCacheTimeout)
        @_lastDevicesStateCacheTimeout = setTimeout( (=>
          @_lastDevicesStateCache = null
        ), 60*1000)
        return devices
      )
      return @_lastDevicesStateCache.then( (devices) -> devices[deviceId] )


    _insertDeviceAttribute: (deviceId, attributeName) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      device = @framework.deviceManager.getDeviceById(deviceId)
      unless device? then throw new Error("#{deviceId} not found.")
      attribute = device.attributes[attributeName]
      unless attribute? then throw new Error("#{deviceId} has no attribute #{attributeName}.")

      expireInfo = @getDeviceAttributeLoggingTime(deviceId, attributeName, attribute.type)

      info = {
        id: null
        type: attribute.type
        expireMs: expireInfo.expireMs
        intervalMs: expireInfo.intervalMs
        lastInsertTime: 0
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