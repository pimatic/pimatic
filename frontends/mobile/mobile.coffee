express = require "express" 
offline = require "connect-offline" 
coffeescript = require 'connect-coffee-script'
modules = require '../../lib/modules'

offlineOptions =
  manifest_path: "/application.manifest"
  use_fs_watch: true
  files: [
    dir: "/public/"
    prefix: "/"
    ,
    dir: "/public/themes/"
    prefix: "/themes/"
   ,
    dir: "/public/themes/images/"
    prefix: "/themes/images/"
    ,
    dir: "/public/roboto/"
    prefix: "/roboto/"
    ,
    dir: "/public/images/"
    prefix: "/images/"
  ]
  networks: ["*"]

class MobileFrontend extends modules.Frontend
  config: null

  useOffline: (app) ->
    cwdBak = process.cwd()
    process.chdir(__dirname)
    app.use offline offlineOptions
    process.chdir(cwdBak)


  init: (app, server, config) =>
    @config = config
    @useOffline app
    app.use coffeescript(
      src: __dirname + "/public-coffee",
      dest: __dirname + '/public',
      bare: true
    )

    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'

    actors = (server.getActorById(a.id) for a in config.actorsToDisplay)

    app.get '/', (req,res) ->
      res.render 'index',
        actors: actors
      
    app.use express.static(__dirname + "/public")

module.exports = new MobileFrontend