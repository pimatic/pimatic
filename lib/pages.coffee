

__ = require("i18n-pimatic").__
Promise = require 'bluebird'
assert = require 'cassert'
_ = require('lodash')
S = require('string')

module.exports = (env) ->

  class PageManager

    constructor: (@framework, @pages) -> #nop

    addPage: (id, page) ->
      if _.findIndex(@pages, {id: id}) isnt -1
        throw new Error('A page with this ID already exists')
      unless page.name?
        throw new Error('No name given')
      @pages.push( page = {
        id: id
        name: page.name
        devices: []
      })
      @framework.saveConfig()
      @framework._emitPageAdded(page)
      return page

    updatePage: (id, page) ->
      assert typeof id is "string"
      assert typeof page is "object"
      assert(if page.name? then typeof page.name is "string" else true)
      assert(if page.devicesOrder? then Array.isArray page.devicesOrder else true)
      thepage = @getPageById(id)
      unless thepage?
        throw new Error('Page not found')
      thepage.name = page.name if page.name?
      if page.devicesOrder?
        thepage.devices = _.sortBy(thepage.devices,  (device) => 
          index = page.devicesOrder.indexOf device.deviceId
          # push it to the end if not found
          return if index is -1 then 99999 else index 
        )
      @framework.saveConfig()
      @framework._emitPageChanged(thepage)
      return thepage

    getPageById: (id) -> _.find(@pages, {id: id})

    addDeviceToPage: (pageId, deviceId) ->
      page = @getPageById(pageId)
      unless page?
        throw new Error('Could not find the page')
      page.devices.push({
        deviceId: deviceId
      })
      @framework.saveConfig()
      @framework._emitPageChanged(page)
      return page

    removeDeviceFromPage: (pageId, deviceId) ->
      page = @getPageById(pageId)
      unless page?
        throw new Error('Could not find the page')
      _.remove(page.devices, {deviceId: deviceId})
      @framework.saveConfig()
      @framework._emitPageChanged(page)
      return page

    removeDeviceFromAllPages: (deviceId) ->
      for page in @pages
        removed = _.remove(page.devices, {deviceId: deviceId})
        if removed.length > 0
          @framework._emitPageChanged(page)
      @framework.saveConfig()

    removePage: (id, page) ->
      removedPage = _.remove(@pages, {id: id})
      @framework.saveConfig() if removedPage.length > 0
      @framework._emitPageRemoved(removedPage[0])
      return removedPage

    getPages: (role = "admin") ->
      @pages.filter (page) ->
        if page.allowedRoles? then page.allowedRoles.indexOf(role) isnt -1 else true

    updatePageOrder: (pageOrder) ->
      assert pageOrder? and Array.isArray pageOrder
      @framework.config.pages = @pages = _.sortBy(@pages,  (page) => 
        index = pageOrder.indexOf page.id 
        return if index is -1 then 99999 else index # push it to the end if not found
      )
      @framework.saveConfig()
      @framework._emitPageOrderChanged(pageOrder)
      return pageOrder

  return exports = { PageManager }
