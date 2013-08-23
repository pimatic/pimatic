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

# A class for all you can switch on and off.
class SwitchActuator extends Actuator
  type: 'BinaryActuator'
  state: null
  actions: ["turnOn", "turnOff", "changeStateTo"]

  turnOn: (callback) ->
    @changeStateTo on, callback

  turnOff: (callback) ->
    @changeStateTo off, callback

  changeStateTo: (state, callback) ->
    throw new Error "Function \"changeStateTo\" is not implemented!"

class PowerSwitch extends SwitchActuator


module.exports.Actuator = Actuator
module.exports.SwitchActuator = SwitchActuator
module.exports.PowerSwitch = PowerSwitch