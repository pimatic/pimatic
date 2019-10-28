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
    toDBBool: (v) => if v then 1 else 0
    fromDBBool: (v) => (v == 1 or v is "1")
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
      super()

    init: () ->
      connection = _.clone(@dbSettings.connection)
      if @dbSettings.client is 'sqlite3'
        (
          if connection.filename is ':memory:'
            connection.filename = 'file::memory:?cache=shared'
          else
            connection.filename = path.resolve(@framework.maindir, '../..', connection.filename)
        )

      pending = Promise.resolve()

      dbPackageToInstall = @dbSettings.client
      try
        require.resolve(dbPackageToInstall)
      catch e
        unless e.code is 'MODULE_NOT_FOUND' then throw e
        env.logger.info(
          "Installing database package #{dbPackageToInstall}, this can take some minutes"
        )
        if dbPackageToInstall is "sqlite3"
          dbPackageToInstall = "sqlite3@4.0.9"
        pending = @framework.pluginManager.spawnPpm(
          ['install', dbPackageToInstall, '--unsafe-perm']
        )

      return pending.then( =>
        @knex = Knex(
          client: @dbSettings.client
          connection: connection
          pool:
            min: 1
            max: 1
          useNullAsDefault: true
        )

        @framework.on('destroy', (context) =>
          @framework.removeListener("messageLogged", @messageLoggedListener)
          @framework.removeListener('deviceAttributeChanged', @deviceAttributeChangedListener)
          clearTimeout(@deleteExpiredTimeout)
          @_isDestroying = true
          env.logger.info("Flushing database to disk, please wait...")
          context.waitForIt(
            @commitLoggingTransaction().then( () =>
              return @knex.destroy()
            ).then( =>
              env.logger.info("Flushing database to disk, please wait... Done.")
            )
          )
        )
        @knex.subquery = (query) -> this.raw("(#{query.toString()})")
        if @dbSettings.client is "sqlite3"
          return Promise.all([
            # Prevents a shm file to be created for wal index:
            @knex.raw("PRAGMA locking_mode=EXCLUSIVE")
            @knex.raw("PRAGMA synchronous=NORMAL;")
            @knex.raw("PRAGMA auto_vacuum=FULL;")
            # Don't write data to disk inside one transaction, this reduces disk writes
            @knex.raw("PRAGMA cache_spill=false;")
            # Increase the cache size to around 20MB (pagesize=1024B)
            @knex.raw("PRAGMA cache_size=20000;")
            # WAL mode to prevents disk corruption and minimize disk writes
            @knex.raw("PRAGMA journal_mode=WAL;")
          ])

      ).then( =>
        @_createTables()
      ).then( =>
        # Save log-messages
        @framework.on("messageLogged", @messageLoggedListener = ({level, msg, meta}) =>
          if meta?.timestamp and meta.tags?
            @saveMessageEvent(meta.timestamp, level, meta.tags, msg).done()
        )

        # Save device attribute changes
        @framework.on('deviceAttributeChanged',
          @deviceAttributeChangedListener = ({device, attributeName, time, value}) =>
            @saveDeviceAttributeEvent(device.id, attributeName, time, value).done()
        )

        @_updateDeviceAttributeExpireInfos()
        @_updateMessageseExpireInfos()

        deleteExpiredInterval = @_parseTime(@dbSettings.deleteExpiredInterval)
        diskSyncInterval = @_parseTime(@dbSettings.diskSyncInterval)

        minExpireInterval = 1 * 60 * 1000
        if deleteExpiredInterval < minExpireInterval
          env.logger.warn("deleteExpiredInterval can't be less then 1 min, setting it to 1 min.")
          deleteExpiredInterval = minExpireInterval

        if (diskSyncInterval/deleteExpiredInterval % 1) isnt 0
          env.logger.warn("diskSyncInterval should be a multiple of deleteExpiredInterval.")

        syncAllNo = Math.max(Math.ceil(diskSyncInterval/deleteExpiredInterval), 1)
        deleteNo = 0

        doDeleteExpired = ( =>
          env.logger.debug("Deleting expired logged values") if @dbSettings.debug
          deleteNo++
          Promise.resolve().then( =>
            env.logger.debug("Deleting expired events") if @dbSettings.debug
            return @_deleteExpiredDeviceAttributes().then( =>
              env.logger.debug("Deleting expired events... Done.") if @dbSettings.debug
            )
          )
          .then( =>
            env.logger.debug("Deleting expired message") if @dbSettings.debug
            return @_deleteExpiredMessages().then( =>
              env.logger.debug("Deleting expired message... Done.") if @dbSettings.debug
            )
          )
          .then( =>
            if deleteNo % syncAllNo is 0
              env.logger.debug("Done -> flushing to disk") if @dbSettings.debug
              next = @commitLoggingTransaction().then( =>
                env.logger.debug("-> done.") if @dbSettings.debug
              )
            else
              next = Promise.resolve()
            return next.then( =>
              @deleteExpiredTimeout = setTimeout(doDeleteExpired, deleteExpiredInterval)
            )
          ).catch( (error) =>
            env.logger.error(error.message)
            env.logger.debug(error.stack)
          ).done()
        )

        @deleteExpiredTimeout = setTimeout(doDeleteExpired, deleteExpiredInterval)
        return
      )

    loggingTransaction: ->
      unless @_loggingTransaction?
        @_loggingTransaction = new Promise( (resolve, reject) =>
          @knex.transaction( (trx) =>
            transactionInfo = {
              trx,
              count: 0,
              resolve: null
            }
            resolve(transactionInfo)
          ).catch(reject)
        )
      return @_loggingTransaction

    doInLoggingTransaction: (callback) ->
      return new Promise(  (resolve, reject) =>
        @_loggingTransaction = @loggingTransaction().then( (transactionInfo) =>
          action = callback(transactionInfo.trx)
          # must return a promise
          transactionInfo.count++
          actionCompleted = ->
            transactionInfo.count--
            if transactionInfo.count is 0 and transactionInfo.resolve?
              transactionInfo.resolve()
          # remove when action finished
          action.then(actionCompleted, actionCompleted)
          resolve(action)
          return transactionInfo
        ).catch(reject)
      )

    commitLoggingTransaction: ->
      promise = Promise.resolve()
      if @_loggingTransaction?
        promise = @_loggingTransaction.then( (transactionInfo) =>
          env.logger.debug("Committing") if @dbSettings.debug
          doCommit = =>
            return transactionInfo.trx.commit()
          if transactionInfo.count is 0
            return doCommit()
          else
            return new Promise( (resolve) ->
              transactionInfo.resolve = ->
                doCommit()
                resolve()
            )
        )
        @_loggingTransaction = null
      return promise.catch( (error) =>
        env.logger.error(error.message)
        env.logger.debug(error.stack)
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
        table.increments('id').primary().unique()
        table.string('deviceId')
        table.string('attributeName')
        table.string('type')
        table.boolean('discrete')
        table.timestamp('lastUpdate').nullable()
        table.string('lastValue').nullable()
        table.index(['deviceId','attributeName'], 'deviceAttributeDeviceIdAttributeName')
        table.index(['deviceId'], 'deviceAttributeDeviceId')
        table.index(['attributeName'], 'deviceAttributeAttributeName')
      )

      for tableName, tableInfo of dbMapping.attributeValueTables
        pending.push createTableIfNotExists(tableName, (table) =>
          table.increments('id').primary()
          table.timestamp('time').index()
          table.integer('deviceAttributeId')
            .unsigned()
            .references('id')
            .inTable('deviceAttribute')
          table[tableInfo.valueColumnType]('value')
        ).then(tableName, (table) =>
          return table.index(['deviceAttributeId','time'], 'deviceAttributeIdTime')
        )

      return Promise.all(pending)

    getDeviceAttributeLogging: () ->
      return _.clone(@dbSettings.deviceAttributeLogging)

    setDeviceAttributeLogging: (deviceAttributeLogging) ->
      @dbSettings.deviceAttributeLogging = deviceAttributeLogging
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
      possibleTypes = ["number", "string", "boolean", "date", "discrete", "continuous", "*"]
      while i >= 0
        entry = entries[i]
        #legazy support
        if entry.time?
          entry.expire = entry.time
          delete entry.time
        unless entry.type?
          entry.type = "*"

        unless entry.type in possibleTypes
          throw new Error("Type option in database config must be one of #{possibleTypes}")

        # Get expire info from entry or create it
        expireInfo = entry.expireInfo
        unless expireInfo?
          expireInfo = {
            expireMs: 0
            interval: 0
            whereSQL: ""
          }
          info = {expireInfo}
          info.__proto__ = entry.__proto__
          entry.__proto__ = info
        # Generate sql where to use on deletion
        ownWhere = ["1=1"]
        if entry.expire?
          if entry.deviceId isnt '*'
            ownWhere.push "deviceId='#{entry.deviceId}'"
          if entry.attributeName isnt '*'
            ownWhere.push "attributeName='#{entry.attributeName}'"
          if entry.type isnt '*'
            if entry.type is "continuous"
              ownWhere.push "discrete=0"
            else if entry.type is "discrete"
              ownWhere.push "discrete=1"
            else
              ownWhere.push "type='#{entry.type}'"
        if entry.expire?
          ownWhere = ownWhere.join(" and ")
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
        #legazy support
        if entry.time?
          entry.expire = entry.time
          delete entry.time
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


    getDeviceAttributeLoggingTime: (deviceId, attributeName, type, discrete) ->
      expireMs = 0
      expire = "0"
      intervalMs = 0
      interval = "0"
      for entry in @dbSettings.deviceAttributeLogging
        matches = (
          (entry.deviceId is '*' or entry.deviceId is deviceId) and
          (entry.attributeName is '*' or entry.attributeName is attributeName) and
          (
            switch entry.type
              when '*' then true
              when "discrete" then discrete
              when "continuous" then not discrete
              else  entry.type is type
            )
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
      expireMs = null
      for entry in @dbSettings.messageLogging
        if (
          (entry.level is "*" or entry.level is level) and
          (entry.tags.length is 0 or (t for t in entry.tags when t in tags).length > 0)
        )
          expireMs = entry.expireInfo.expireMs
      return expireMs

    _deleteExpiredDeviceAttributes: ->
      return @doInLoggingTransaction( (trx) =>
        return Promise.each(@dbSettings.deviceAttributeLogging, (entry) =>
          if entry.expire?
            subquery = @knex('deviceAttribute').select('id')
            subquery.whereRaw(entry.expireInfo.whereSQL)
            subqueryRaw = "deviceAttributeId in (#{subquery.toString()})"
            return Promise.each(_.keys(dbMapping.attributeValueTables), (tableName) =>
              if @_isDestroying then return
              del = @knex(tableName).transacting(trx)
              if @dbSettings.client is "sqlite3"
                del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
              else
                del.whereRaw(
                  'time < FROM_UNIXTIME(?)',
                  [
                    @_convertTimeForDatabase(
                      parseFloat((new Date()).getTime() - entry.expireInfo.expireMs)
                    )
                  ]
                )
              del.whereRaw(subqueryRaw)
              query = del.del()
              env.logger.debug("query:", query.toString()) if @dbSettings.debug
              return query
            )
        )
      )

    _deleteExpiredMessages: ->
      return @doInLoggingTransaction( (trx) =>
        return Promise.each(@dbSettings.messageLogging, (entry) =>
          if @_isDestroying then return
          del = @knex('message').transacting(trx)
          if @dbSettings.client is "sqlite3"
            del.where('time', '<', (new Date()).getTime() - entry.expireInfo.expireMs)
          else
            del.whereRaw(
              'time < FROM_UNIXTIME(?)',
              [
                @_convertTimeForDatabase(
                  parseFloat((new Date()).getTime() - entry.expireInfo.expireMs)
                )
              ]
            )
          del.whereRaw(entry.expireInfo.whereSQL)
          query = del.del()
          env.logger.debug("query:", query.toString()) if @dbSettings.debug
          return query
        )
      )

    saveMessageEvent: (time, level, tags, text) ->
      @emit 'log', {time, level, tags, text}
      #assert typeof time is 'number'
      assert Array.isArray(tags)
      assert typeof level is 'string'
      assert level in _.keys(dbMapping.logLevelToInt)

      expireMs = @getMessageLoggingTime(time, level, tags, text)
      if expireMs is 0
        return Promise.resolve()

      return @doInLoggingTransaction( (trx) =>
        return @knex('message').transacting(trx).insert(
          time: time
          level: dbMapping.logLevelToInt[level]
          tags: JSON.stringify(tags)
          text: text
        ).return()
      )

    saveDeviceAttributeEvent: (deviceId, attributeName, time, value) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0
      @emit 'device-attribute-save', {deviceId, attributeName, time, value}

      if value isnt value # just true for Number.NaN
        # Don't insert NaN values into the database
        return Promise.resolve()

      return @_getDeviceAttributeInfo(deviceId, attributeName).then( (info) =>
        return @doInLoggingTransaction( (trx) =>
          # insert into value table
          tableName = dbMapping.typeToAttributeTable(info.type)
          timestamp = time.getTime()
          if info.expireMs is 0
            # value expires immediately
            doInsert = false
          else
            if info.intervalMs is 0 or timestamp - info.lastInsertTime > info.intervalMs
              doInsert = true
            else
              doInsert = false
          if doInsert
            info.lastInsertTime = timestamp
            insert1 = @knex(tableName).transacting(trx).insert(
              time: time
              deviceAttributeId: info.id
              value: value
            )
          else
            insert1 = Promise.resolve()
          # and update lastValue in attributeInfo
          insert2 = @knex('deviceAttribute').transacting(trx)
            .where(
              id: info.id
            )
            .update(
              lastUpdate: time
              lastValue: value
            )
          return Promise.all([insert1, insert2])
        )
      )


    _buildMessageWhere: (query, {level, levelOp, after, before, tags, offset, limit}) ->
      if level?
        unless levelOp then levelOp = '='
        if Array.isArray(level)
          level = _.map(level, (l) => dbMapping.logLevelToInt[l])
          query.whereIn('level', level)
        else
          query.where('level', levelOp, dbMapping.logLevelToInt[level])
      if after?
        if @dbSettings.client is "sqlite3"
          query.where('time', '>=', after)
        else
          query.whereRaw('time >= FROM_UNIXTIME(?)', [@_convertTimeForDatabase(parseFloat(after))])
      if before?
        if @dbSettings.client is "sqlite3"
          query.where('time', '<=', before)
        else
          query.whereRaw('time <= FROM_UNIXTIME(?)', [@_convertTimeForDatabase(parseFloat(before))])
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
      return @doInLoggingTransaction( (trx) =>
        query = @knex('message').transacting(trx).count('*')
        @_buildMessageWhere(query, criteria)
        return Promise.resolve(query).then( (result) => result[0]["count(*)"] )
      )

    queryMessagesTags: (criteria = {})->
      return @doInLoggingTransaction( (trx) =>
        query = @knex('message').transacting(trx).distinct('tags').select()
        @_buildMessageWhere(query, criteria)
        return Promise.resolve(query).then( (tags) =>
          _(tags).map((r)=>JSON.parse(r.tags)).flatten().uniq().valueOf()
        )
      )
    queryMessages: (criteria = {}) ->
      return @doInLoggingTransaction( (trx) =>
        query = @knex('message').transacting(trx).select('time', 'level', 'tags', 'text')
        @_buildMessageWhere(query, criteria)
        return Promise.resolve(query).then( (msgs) =>
          for m in msgs
            m.tags = JSON.parse(m.tags)
            m.level = dbMapping.logIntToLevel[m.level]
          return msgs
        )
      )

    deleteMessages: (criteria = {}) ->
      return @doInLoggingTransaction( (trx) =>
        query = @knex('message').transacting(trx)
        @_buildMessageWhere(query, criteria)
        return Promise.resolve((query).del())
      )

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
        if @dbSettings.client is "sqlite3"
          timeSelect = 'time AS time'
        else
          timeSelect = @knex.raw('(UNIX_TIMESTAMP(time)*1000) AS time')
        query.select(
          'deviceAttribute.deviceId AS deviceId',
          'deviceAttribute.attributeName AS attributeName',
          'deviceAttribute.type AS type',
          timeSelect,
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
        if @dbSettings.client is "sqlite3"
          query.where('time', '>=', after)
        else
          query.whereRaw('time >= FROM_UNIXTIME(?)', [@_convertTimeForDatabase(parseFloat(after))])
      if before?
        if @dbSettings.client is "sqlite3"
          query.where('time', '<=', before)
        else
          query.whereRaw('time <= FROM_UNIXTIME(?)', [@_convertTimeForDatabase(parseFloat(before))])
      query.orderBy(order, orderDirection)
      if offset? then query.offset(offset)
      if limit? then query.limit(limit)
      return query

    queryDeviceAttributeEvents: (queryCriteria) ->
      @doInLoggingTransaction( (trx) =>
        query = @_buildQueryDeviceAttributeEvents(queryCriteria).transacting(trx)
        env.logger.debug("Query:", query.toString()) if @dbSettings.debug
        time = new Date().getTime()
        return Promise.resolve(query).then( (result) =>
          timeDiff = new Date().getTime()-time
          if @dbSettings.debug
            env.logger.debug("Quering #{result.length} events took #{timeDiff}ms.")
          for r in result
            if r.type is "boolean"
              # convert numeric or string value from db to boolean
              r.value = dbMapping.fromDBBool(r.value)
            else if r.type is "number"
              # convert string values to number
              r.value = parseFloat(r.value)
          return result
        )
      )

    queryDeviceAttributeEventsCount: () ->
      @doInLoggingTransaction( (trx) =>
        pending = []
        for tableName in _.keys(dbMapping.attributeValueTables)
          pending.push @knex(tableName).transacting(trx).count('* AS count')
        return Promise.all(pending).then( (counts) =>
          count = 0
          for c in counts
            count += c[0].count
          return count
        )
      )

    queryDeviceAttributeEventsDevices: () ->
      @doInLoggingTransaction( (trx) =>
        return @knex('deviceAttribute').transacting(trx).select(
          'id',
          'deviceId',
          'attributeName',
          'type'
        )
      )

    queryDeviceAttributeEventsInfo: () ->
      @doInLoggingTransaction( (trx) =>
        return @knex('deviceAttribute').transacting(trx).select(
          'id',
          'deviceId',
          'attributeName',
          'type',
          'discrete'
        ).then( (results) =>
          for result in results
            result.discrete = dbMapping.fromDBBool(result.discrete)
            info = @getDeviceAttributeLoggingTime(
              result.deviceId, result.attributeName, result.type, result.discrete
            )
            result.interval = info.interval
            result.expire = info.expire
            # device = @framework.deviceManager.getDeviceById(result.deviceId)
            # if device?
            #   attribute = device.attributes[result.attributeName]
            #   if attribute?
            #     if attribute.discrete
            #       result.interval = 'all'
          return results
        )
      )

    queryDeviceAttributeEventsCounts: () ->
      @doInLoggingTransaction( (trx) =>
        queries = []
        for tableName in _.keys(dbMapping.attributeValueTables)
          queries.push(
            @knex(tableName).transacting(trx)
              .select('deviceAttributeId').count('id')
              .groupBy('deviceAttributeId')
          )
        return Promise
          .reduce(queries, (all, result) => all.concat result)
          .each( (entry) =>
            entry.count = entry['count("id")']
            entry['count("id")'] = undefined
          )
      )

    runVacuum: ->
      @commitLoggingTransaction().then( =>
        return @knex.raw('VACUUM;')
      )


    checkDatabase: () ->
      return @doInLoggingTransaction( (trx) =>
        return @knex('deviceAttribute').transacting(trx).select(
          'id'
          'deviceId',
          'attributeName',
          'type',
          'discrete'
        ).then( (results) =>
          problems = []
          for result in results
            result.discrete = dbMapping.fromDBBool(result.discrete)
            device = @framework.deviceManager.getDeviceById(result.deviceId)
            unless device?
              problems.push {
                id: result.id
                deviceId: result.deviceId
                attribute: result.attributeName
                description: "No device with the ID \"#{result.deviceId}\" found."
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
                    description: "Attribute \"#{result.attributeName}\" of  " +
                             "\"#{result.deviceId}\" has the wrong type"
                    action: "delete"
                  }
                else if attribute.discrete isnt result.discrete
                  problems.push {
                    id: result.id
                    deviceId: result.deviceId
                    attribute: result.attributeName
                    description: "Attribute \"#{result.attributeName}\" of" +
                             "\"#{result.deviceId}\" discrete flag is wrong."
                    action: "update"
                  }
          return problems
        )
      )

    deleteDeviceAttribute: (id) ->
      assert typeof id is "number"
      @doInLoggingTransaction( (trx) =>
        return @knex('deviceAttribute').transacting(trx).where('id', id).del().then( () =>
          for key, entry of dbMapping.deviceAttributeCache
            if entry.id is id
              delete dbMapping.deviceAttributeCache[key]
          awaiting = []
          for tableName, tableInfo of dbMapping.attributeValueTables
            awaiting.push @knex(tableName).transacting(trx).where('deviceAttributeId', id).del()
          return Promise.all(awaiting)
        )
      )

    updateDeviceAttribute: (id) ->
      assert typeof id is "number"
      return @doInLoggingTransaction( (trx) =>
        @knex('deviceAttribute').transacting(trx)
          .select('deviceId', 'attributeName')
          .where(id: id).then( (results) =>
            if results.length is 1
              result = results[0]
              fullQualifier = "#{result.deviceId}.#{result.attributeName}"
              device = @framework.deviceManager.getDeviceById(result.deviceId)
              unless device? then throw new Error("#{result.deviceId} not found.")
              attribute = device.attributes[result.attributeName]
              unless attribute?
                new Error("#{result.deviceId} has no attribute #{result.attributeName}.")
              info = dbMapping.deviceAttributeCache[fullQualifier]
              info.discrete = attribute.discrete if info?
              return update = @knex('deviceAttribute').transacting(trx)
                .where(id: id).update(
                  discrete: dbMapping.toDBBool(attribute.discrete)
                ).return()
            else
              return
        )
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
        return @doInLoggingTransaction( (trx) =>
          query = @knex(dbMapping.typeToAttributeTable(info.type)).transacting(trx)
          unless groupByTime?
            query.select('time', 'value')
          else
            if @dbSettings.client is "sqlite3"
              query.select(@knex.raw('MIN(time) AS time'), @knex.raw('AVG(value) AS value'))
            else
              query.select(
                @knex.raw('MIN(UNIX_TIMESTAMP(time) * 1000) AS time'),
                @knex.raw('AVG(value) AS value')
              )
          query.where('deviceAttributeId', info.id)
          if after?
            if @dbSettings.client is "sqlite3"
              query.where('time', '>=', @_convertTimeForDatabase(parseFloat(after)))
            else
              query.whereRaw(
                'time >= FROM_UNIXTIME(?)',
                [@_convertTimeForDatabase(parseFloat(after))]
              )
          if before?
            if @dbSettings.client is "sqlite3"
              query.where('time', '<=', @_convertTimeForDatabase(parseFloat(before)))
            else
              query.whereRaw(
                'time <= FROM_UNIXTIME(?)',
                [@_convertTimeForDatabase(parseFloat(before))]
              )
          if order?
            query.orderBy(order, orderDirection)
          if groupByTime?
            groupByTime = parseFloat(groupByTime)
            if @dbSettings.client is "sqlite3"
              query.groupByRaw("time/#{groupByTime}")
            else
              query.groupByRaw("UNIX_TIMESTAMP(time)/#{groupByTime}")
          if offset? then query.offset(offset)
          if limit? then query.limit(limit)
          env.logger.debug("query:", query.toString()) if @dbSettings.debug
          time = new Date().getTime()
          return Promise.resolve(query).then( (result) =>
            timeDiff = new Date().getTime()-time
            if @dbSettings.debug
              env.logger.debug("querying #{result.length} events took #{timeDiff}ms.")
            if info.type is "boolean"
              for r in result
                # convert numeric or string value from db to boolean
                r.value = dbMapping.fromDBBool(r.value)
            else if info.type is "number"
              for r in result
                # convert string values to number
                r.value = parseFloat(r.value)
            return result
          )
        )
      )

    _getDeviceAttributeInfo: (deviceId, attributeName) ->
      fullQualifier = "#{deviceId}.#{attributeName}"
      info = dbMapping.deviceAttributeCache[fullQualifier]
      return (
        if info?
          unless info.expireMs?
            expireInfo = @getDeviceAttributeLoggingTime(
              deviceId, attributeName, info.type, info.discrete
            )
            info.expireMs = expireInfo.expireMs
            info.intervalMs = expireInfo.intervalMs
            info.lastInsertTime = 0
          Promise.resolve(info)
        else @_insertDeviceAttribute(deviceId, attributeName)
      )


    getLastDeviceState: (deviceId) ->
      if @_lastDevicesStateCache?
        return @_lastDevicesStateCache.then( (devices) -> devices[deviceId] )
      return @doInLoggingTransaction( (trx) =>
        # query all devices for performance reason and cache the result
        @_lastDevicesStateCache = @knex('deviceAttribute').transacting(trx).select(
          'deviceId', 'attributeName', 'type', 'lastUpdate', 'lastValue'
        ).then( (result) =>
          #group by device
          devices = {}
          convertValue = (value, type) ->
            unless value? then return null
            return (
              switch type
                when 'number' then parseFloat(value)
                when 'boolean' then dbMapping.fromDBBool(value)
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
      )

    _convertTimeForDatabase: (timestamp) ->
      #For mysql we need a timestamp in seconds
      if @dbSettings.client is "sqlite3"
        return timestamp
      else
        return Math.floor(timestamp / 1000)

    _insertDeviceAttribute: (deviceId, attributeName) ->
      assert typeof deviceId is 'string' and deviceId.length > 0
      assert typeof attributeName is 'string' and attributeName.length > 0

      device = @framework.deviceManager.getDeviceById(deviceId)
      unless device? then throw new Error("#{deviceId} not found.")
      attribute = device.attributes[attributeName]
      unless attribute? then throw new Error("#{deviceId} has no attribute #{attributeName}.")

      expireInfo = @getDeviceAttributeLoggingTime(
        deviceId, attributeName, attribute.type, attribute.discrete
      )

      info = {
        id: null
        type: attribute.type
        discrete: attribute.discrete
        expireMs: expireInfo.expireMs
        intervalMs: expireInfo.intervalMs
        lastInsertTime: 0
      }

      ###
        Don't create a new entry for the device if an entry with the attributeName and deviceId
        already exists.
      ###
      return @doInLoggingTransaction( (trx) =>
        if @dbSettings.client is "sqlite3"
          statement = """
            INSERT INTO deviceAttribute(deviceId, attributeName, type, discrete)
            SELECT
              '#{deviceId}' AS deviceId,
              '#{attributeName}' AS attributeName,
              '#{info.type}' as type,
              #{dbMapping.toDBBool(info.discrete)} as discrete
            WHERE 0 = (
              SELECT COUNT(*)
              FROM deviceAttribute
              WHERE deviceId = '#{deviceId}' and attributeName = '#{attributeName}'
            );
            """
        else
          statement = """
            INSERT INTO deviceAttribute(deviceId, attributeName, type, discrete)
            SELECT * FROM
              ( SELECT '#{deviceId}' AS deviceId,
              '#{attributeName}' AS attributeName,
              '#{info.type}' as type,
              #{dbMapping.toDBBool(info.discrete)} as discrete
              ) as tmp
            WHERE NOT EXISTS (
              SELECT deviceId, attributeName
              FROM deviceAttribute
              WHERE deviceId = '#{deviceId}' and attributeName = '#{attributeName}'
            ) LIMIT 1;
            """
        return @knex.raw(
          statement
        ).transacting(trx).then( =>
          @knex('deviceAttribute').transacting(trx).select('id').where(
            deviceId: deviceId
            attributeName: attributeName
          ).then( ([result]) =>
            info.id = result.id
            assert info.id? and typeof info.id is "number"
            update = Promise.resolve()
            if (not info.discrete?) or dbMapping.fromDBBool(info.discrete) isnt attribute.discrete
              update = @knex('deviceAttribute').transacting(trx)
                .where(id: info.id).update(
                  discrete: dbMapping.toDBBool(attribute.discrete)
                )
            info.discrete = attribute.discrete
            fullQualifier = "#{deviceId}.#{attributeName}"
            return update.then( => (dbMapping.deviceAttributeCache[fullQualifier] = info) )
          )
        )
      )


  return exports = { Database }
