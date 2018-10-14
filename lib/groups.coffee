

__ = require("i18n-pimatic").__
Promise = require 'bluebird'
assert = require 'cassert'
_ = require('lodash')
S = require('string')

module.exports = (env) ->

  class GroupManager

    constructor: (@framework, @groups) -> #nop

    addGroup: (id, group) ->
      if _.findIndex(@groups, {id: id}) isnt -1
        throw new Error('A group with this ID already exists')
      unless group.name?
        throw new Error('No name given')
      @groups.push( group = {
        id: id
        name: group.name
        devices: []
        rules: []
        variables: []
      })

      @framework.saveConfig()
      @framework._emitGroupAdded(group)
      return group

    updateGroup: (id, patch) ->
      index = _.findIndex(@groups, {id: id})
      if index is -1
        throw new Error('Group not found')
      group = @groups[index]

      if patch.name?
        group.name = patch.name
      if patch.devicesOrder?
        group.devices = _.sortBy(group.devices, (deviceId) => 
          index = patch.devicesOrder.indexOf deviceId
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      if patch.rulesOrder?
        group.rules = _.sortBy(group.rules, (ruleId) =>
          index = patch.rulesOrder.indexOf ruleId
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      if patch.variablesOrder
        group.variables = _.sortBy(group.variables, (variableName) =>
          index = patch.variablesOrder.indexOf variableName
          return if index is -1 then 99999 else index # push it to the end if not found
        )
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    getGroupById: (id) -> _.find(@groups, {id: id})

    addDeviceToGroup: (groupId, deviceId, position) ->
      assert(typeof deviceId is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfDevice(deviceId)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.devices, (id) => id is deviceId)
        @framework._emitGroupChanged(oldGroup)
      unless position? or position >= group.devices.length
        group.devices.push(deviceId)
      else
        group.devices.splice(position, 0, deviceId)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    getGroupOfRule: (ruleId) ->
      for g in @groups
        index = _.indexOf(g.rules, ruleId)
        if index isnt -1 then return g
      return null

    addRuleToGroup: (groupId, ruleId, position) ->
      assert(typeof ruleId is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfRule(ruleId)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.rules, (id) => id is ruleId)
        @framework._emitGroupChanged(oldGroup)
      unless position? or position >= group.rules.length
        group.rules.push(ruleId)
      else
        group.rules.splice(position, 0, ruleId)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    getGroupOfVariable: (variableName) ->
      for g in @groups
        index = _.indexOf(g.variables, variableName)
        if index isnt -1 then return g
      return null

    removeDeviceFromGroup: (groupId, deviceId) ->
      group = @getGroupOfDevice(deviceId)
      unless group?
        throw new Error('Device is in no group')
      if group.id isnt groupId
        throw new Error("Device is not in group #{groupId}")
      _.remove(group.devices, (id) => id is deviceId)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    removeRuleFromGroup: (groupId, ruleId) ->
      group = @getGroupOfRule(ruleId)
      unless group?
        throw new Error('Rule is in no group')
      if group.id isnt groupId
        throw new Error("Rule is not in group #{groupId}")
      _.remove(group.rules, (id) => id is ruleId)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    removeVariableFromGroup: (groupId, variableName) ->
      group = @getGroupOfVariable(variableName)
      unless group?
        throw new Error('Variable is in no group')
      if group.id isnt groupId
        throw new Error("Variable is not in group #{groupId}")
      _.remove(group.variables, (name) => name is variableName)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    addVariableToGroup: (groupId, variableName, position) ->
      assert(typeof variableName is "string")
      assert(typeof groupId is "string")
      assert(if position? then typeof position is "number" else true)
      group = @getGroupById(groupId)
      unless group?
        throw new Error('Could not find the group')
      oldGroup = @getGroupOfVariable(variableName)
      if oldGroup?
        #remove rule from all other groups
        _.remove(oldGroup.variables, (name) => name is variableName)
        @framework._emitGroupChanged(oldGroup)
      unless position? or position >= group.variables.length
        group.variables.push(variableName)
      else
        group.variables.splice(position, 0, variableName)
      @framework.saveConfig()
      @framework._emitGroupChanged(group)
      return group

    removeGroup: (id, page) ->
      removedGroup = _.remove(@groups, {id: id})
      @framework.saveConfig() if removedGroup.length > 0
      @framework._emitGroupRemoved(removedGroup[0])
      return removedGroup

    getGroupOfDevice: (deviceId) ->
      for g in @groups
        index = _.indexOf(g.devices, deviceId)
        if index isnt -1 then return g
      return null

    getGroups: () ->
      return @groups

    updateGroupOrder: (groupOrder) ->
      assert groupOrder? and Array.isArray groupOrder
      @framework.config.groups = @groups = _.sortBy(@groups,  (group) =>
        index = groupOrder.indexOf group.id
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @framework.saveConfig()
      @framework._emitGroupOrderChanged(groupOrder)
      return groupOrder

  return exports = { GroupManager }
