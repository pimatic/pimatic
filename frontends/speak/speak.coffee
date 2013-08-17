modules = require '../../lib/modules'

class SpeakFrontend extends modules.Frontend
  actions: []

  init: (app, server, @config) =>
    _this = this

    app.get "/api/speak", (req, res, next) ->
      query = require("url").parse(req.url, true).query
      console.log query
      if (not query?) or (typeof query["word[]"] is "undefined")
        res.send 400, "Illegal Request"
      words = query["word[]"]
      words = (if Array.isArray words then words else [words])
      found = false
      for word in words
        found = _this.handleWord res, word
      unless found then res.send 200, "Nicht gefunden: #{words[0]}" 

    @addActorAction actor for id, actor of server.actors 
    server.on "actor", @addActorAction

  addActorAction: (actor) =>
    _this = this
    if actor.hasAction "turnOn"
      _this.addAction 
        words: ["#{actor.name} an", "#{actor.name} ein"]
        callback: (str, res) ->
          actor.turnOn (e) ->
            res.send 200, "#{actor.name} angeschaltet"
    if actor.hasAction "turnOff"
      _this.addAction 
        words: "#{actor.name} aus"
        callback: (str, res) ->
          actor.turnOff (e) ->
            res.send 200, "#{actor.name} ausgeschalten"

  addAction: (action) ->
    @actions.push action

  handleWord: (res, data) ->
    found = no
    for e in @actions
      if not e.words?
        if e.callback data, res
          found = yes
          break
      else if typeof e.words is "string"   
        if data.toLowerCase() is e.words.toLowerCase()
          e.callback data, res
          found = yes
          break
      else if Array.isArray e.words
        for word in e.words
          if data.toLowerCase() is word.toLowerCase()
            e.callback data, res
            found = yes
            break
      if found then break
    return found

module.exports = new SpeakFrontend