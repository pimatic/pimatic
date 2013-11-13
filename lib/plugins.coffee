class Plugin
  name: null
  init: ->
    throw new Error("your plugin must implement init")

module.exports.Plugin = Plugin