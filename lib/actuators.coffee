# Povides the `Actuator` class and some basic common subclasses for the Backend modules. 
assert = require 'assert'

# An Actuator is an physical or logical element you can control by triggering an action on it.
# For example a power outlet, a light or door opener.
class Actuator
  # Defines the actions an Actuator has.
  actions: []
  # A unic id defined by the config or by the backend module that provies the actuator.
  id: null
  # The name of the actuator to display at the frontend.
  name: null

  # Checks if the actuator has a given action.
  hasAction: (name) ->
    name in @actions

# A BinaryActuator 
class BinaryActuator extends Actuator
  type: 'BinaryActuator'
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

class PowerOutlet extends BinaryActuator
    type: 'PowerOutlet'


module.exports.Actuator = Actuator
module.exports.BinaryActuator = BinaryActuator
module.exports.PowerOutlet = PowerOutlet