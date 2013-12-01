# ##Dependencies
assert = require 'cassert'
express = require "express" 

module.exports = (env) ->

  # ##Filebrowser
  class FileBrowser extends env.plugins.Plugin
    init: (app, server, @config) ->
      env.helper.checkConfig env, 'frontend.filebrowser', ->
        assert config.mappings? and Array.isArray config.mappings

      for mapping in config.mappings
        app.use mapping.path, express.directory mapping.directory, icons: true
        app.use mapping.path, express.static mapping.directory

  return new FileBrowser 