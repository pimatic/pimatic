express = require "express" 
modules = require "../../lib/modules"
helper = require "../../lib/helper"
should = require 'should'

class FileBrowser extends modules.Frontend
  init: (app, server, @config) ->
    helper.checkConfig 'frontend.filebrowser', ->
      config.should.have.property("mappings").be.instanceOf(Array)

    for mapping in config.mappings
      app.use mapping.path, express.directory mapping.directory, icons: true
      app.use mapping.path, express.static mapping.directory

module.exports = new FileBrowser 