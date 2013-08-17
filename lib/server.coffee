should = require 'should'
assert = require 'assert'
helper = require './helper'
actors = require './actors'
modules = require './modules'

class Server extends require('events').EventEmitter
  frontends: []
  backends: []
  actors: []

  constructor: (app, config) ->
    should.exist app
    should.exist config
    helper.checkConfig null, ->
      config.should.be.a 'object', "config is no object?"
      config.should.have.property('frontends').instanceOf Array, "frontends should be an array"
      config.should.have.property('backends').instanceOf Array, "backends should be an array"
      config.should.have.property('actors').instanceOf Array, "actors should be an array"

    @app = app
    @config = config
    @loadBackends()
    @loadFrontends()


  loadBackends: ->
    for beConf in @config.backends
      should.exist beConf
      beConf.should.be.a 'object'
      beConf.should.have.property 'module'

      console.log "loading backend: \"#{beConf.module}\"..."
      be = require "../backends/" + beConf.module
      @registerBackend be, beConf

  loadFrontends: ->
    for feConf in @config.frontends
      should.exist feConf
      feConf.should.be.a 'object'
      feConf.should.have.property 'module'

      console.log "loading frontend: \"#{feConf.module}\"..."
      fe = require "../frontends/" + feConf.module
      @registerFrontend fe, feConf

  registerFrontend: (frontend, config) ->
    should.exist frontend
    should.exist config
    frontend.should.be.instanceOf modules.Frontend

    config.should.be.a 'object'
    @frontends.push {module: frontend, config: config}
    @emit "frontend", frontend

  registerBackend: (backend, config) ->
    should.exist backend
    backend.should.be.instanceOf modules.Backend

    @backends.push {module: backend, config: config}
    @emit "backend", backend

  registerActor: (actor) ->
    should.exist actor
    actor.should.be.instanceOf actors.Actor
    actor.should.have.property("name").not.empty
    actor.should.have.property("id").not.empty
    if @actors[actor.id]?
      throw new assert.AssertionError("dublicate actor id \"#{actor.id}\"")

    console.log "new actor \"#{actor.name}\"..."
    @actors[actor.id]=actor
    @emit "actor", actor

  loadActors: ->
    for acConfig in @config.actors
      found = false
      for be in @backends
        found = be.module.createActor acConfig
        if found then break
      unless found
        console.warn "no backend found for actor \"#{acConfig.id}\"!"

  getActorById: (id) ->
    @actors[id]

  init: ->
    b.module.init @, b.config for b in @backends
    @loadActors()
    f.module.init @app, @, f.config for f in @frontends

 module.exports = Server