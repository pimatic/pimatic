express = require "express" 
offline = require "connect-offline" 
coffeescript = require 'connect-coffee-script'
modules = require '../../lib/modules'
socketIo = require 'socket.io'

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


  init: (app, server, @config) =>
    thisClass = @;
    @useOffline app
    app.use coffeescript(
      src: __dirname + "/public-coffee",
      dest: __dirname + '/public',
      bare: true
    )

    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'

    actuators = (server.getActuatorById(a.id) for a in config.actuatorsToDisplay)

    app.get '/', (req,res) ->
      res.render 'index',
        actuators: actuators
      
    app.use express.static(__dirname + "/public")

    # For every webserver
    for webServer in app.webServers
      # Listen for new websocket connections
      io = socketIo.listen webServer
      io.set 'log level', 2 
      # When a new client connects
      io.sockets.on 'connection', (socket) ->
        for actuator in actuators 
          do (actuator) ->
            # * First time push the state to the client
            actuator.getState (error, state) ->
              unless error? then thisClass.emitSwitchState socket, actuator, state
            # * Then forward following state event to the client
            actuator.on "state", (state) ->
              thisClass.emitSwitchState socket, actuator, state

  emitSwitchState: (socket, actuator, state) ->
    socket.emit "switch-status",
      id: actuator.id
      state: state

module.exports = new MobileFrontend