assert = require 'assert'

class Module
  name: null
  init: ->
    throw new assert.AssertionError("your module must implement init")

class Frontend extends Module

class Backend extends Module
  createActor: ->
    throw new assert.AssertionError("your backend must implement createActor")

module.exports.Module = Module
module.exports.Frontend = Frontend
module.exports.Backend = Backend