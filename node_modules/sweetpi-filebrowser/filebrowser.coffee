# #The filebrowser frontend
# A simpe web file browser for a local directory
# 
# ##Example config:
# 
#     {
#        "module": "filebrowser",
#        "mappings": [
#          {
#            "path": "/files",
#            "directory": "/media/usb1"
#          }
#        ]
#      }
# 
# With this config you can browse your files in `/media/usb1` through 
# `http://your-ip/files`

# ##Dependencies
assert = require 'cassert'
express = require "express" 
modules = require "../../lib/modules"
helper = require "../../lib/helper"

# ##Filebrowser
class FileBrowser extends modules.Frontend
  init: (app, server, @config) ->
    helper.checkConfig 'frontend.filebrowser', ->
      assert config.mappings? and Array.isArray config.mappings

    for mapping in config.mappings
      app.use mapping.path, express.directory mapping.directory, icons: true
      app.use mapping.path, express.static mapping.directory

module.exports = new FileBrowser 