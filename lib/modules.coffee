class Module
  name: null
  init: ->
    throw new Error("your module must implement init")

class Frontend extends Module

class Backend extends Module
  # You can overwrite this function, if your module provides the ability to define
  # an actuator in the `settings.json` file. For all defined `actuators` in the settings, this
  # function is called and the options are parsed with the `config` argument. If the actuator
  # belongs to your module you should create a instance of the `Actuator` class and add the 
  # actuator with `server.addActuator` to the server. Then the function the must return `true`. If you 
  # didn't create an `actuator` you should return `false`.
  createActuator: (conifg)->
    false

module.exports.Module = Module
module.exports.Frontend = Frontend
module.exports.Backend = Backend