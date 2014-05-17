assert = require "cassert"
Q = require 'q'
os = require 'os'
fs = require 'fs.extra'

env = require('../startup').env

describe "Eventlog", ->

  #env.logger.info = ->
