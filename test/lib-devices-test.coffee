assert = require "cassert"
Promise = require 'bluebird'
i18n = require 'i18n'
events = require 'events'
_ = require 'lodash'

env = require('../startup').env

describe "ShutterController", ->

  shutterController = new env.devices.ShutterController()

  describe "#_calulateRollingTime()", ->

    it "should throw error when rollingTime is not defined", ->
      try
        shutterController._calulateRollingTime(100)
        assert false
      catch error
        # everything is fine
        assert error.message is "No rolling time configured."
