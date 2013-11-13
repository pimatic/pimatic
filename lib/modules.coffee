class Module
  name: null
  init: ->
    throw new Error("your module must implement init")

module.exports.Module = Module