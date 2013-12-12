# Povides the `Actuator` class and some basic common subclasses for the Backend modules. 
# 
assert = require 'cassert'
Q = require 'q'

# An Actuator is an physical or logical element you can control by triggering an action on it.
# For example a power outlet, a light or door opener.
class Actuator extends require('events').EventEmitter
  # Defines the actions an Actuator has.
  actions: []
  # A unic id defined by the config or by the backend module that provies the actuator.
  id: null
  # The name of the actuator to display at the frontend.
  name: null
  # Events of the actuator.
  events: []

  # Checks if the actuator has a given action.
  hasAction: (name) ->
    name in @actions

  # Checks if the actuator has the given event.
  hasEvent: (name) ->
    name in @events

# A class for all you can switch on and off.
class SwitchActuator extends Actuator
  type: 'SwitchActuator'
  _state: null
  actions: ["turnOn", "turnOff", "changeStateTo", "getState"]
  events: ["state"]

  # Returns a promise
  turnOn: ->
    @changeStateTo on

  # Retuns a promise
  turnOff: ->
    @changeStateTo off

  # Retuns a promise
  changeStateTo: (state) ->
    throw new Error "Function \"changeStateTo\" is not implemented!"

  getState: ->
    self = this
    return Q.fcall -> self._state

  _setState: (state) ->
    self = this
    self._state = state
    self.emit "state", state

class PowerSwitch extends SwitchActuator


module.exports.Actuator = Actuator
module.exports.SwitchActuator = SwitchActuator
module.exports.PowerSwitch = PowerSwitch