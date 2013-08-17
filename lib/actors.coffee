class Actor
  type: 'unknwon'
  actions: []
  name: null
  hasAction: (name) ->
    name in @actions

class BinaryActor extends Actor
  type: 'BinaryActor'
  state: null
  actions: ["turnOn", "turnOff"]

  _turnOn: ->
    @state = on

  _turnOff: ->
    @state = off

  setState: (state, callback) ->
    throw 'Error' unless typeof state?
    if state then @turnOn callback
    else @turnOff callback

class PowerOutlet extends BinaryActor
    type: 'PowerOutlet'


module.exports.Actor = Actor
module.exports.BinaryActor = BinaryActor
module.exports.PowerOutlet = PowerOutlet