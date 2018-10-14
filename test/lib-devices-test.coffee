assert = require "cassert"
Promise = require 'bluebird'
i18n = require 'i18n-pimatic'
events = require 'events'

env = require('../startup').env

describe "ShutterController", ->

  class DummyShutter extends env.devices.ShutterController

    id: "dummyShutter"
    name: "DummyShutter"

    moveToPosition: (position) ->
      # do nothing
      return Promise.resolve()

    stop: ->
      return Promise.resolve()

  shutter = null

  beforeEach ->
    shutter = new DummyShutter()

  describe "#_calculateRollingTime()", ->

    it "should throw error when rollingTime is not defined", ->
      try
        shutter._calculateRollingTime(100)
        assert false
      catch error
        # everything is fine
        assert error.message is "No rolling time configured."

    it "should throw error when percentage out of range", ->
      test = (percentage) ->
        try
          shutter._calculateRollingTime(percentage)
          assert false
        catch error
          # everything is fine
          assert error.message is "percentage must be between 0 and 100"
      test(-1)
      test(101)

    it "should calculate rolling time", ->
      shutter.rollingTime = 1
      assert shutter._calculateRollingTime(100) == 1000
      assert shutter._calculateRollingTime(0) == 0
      assert shutter._calculateRollingTime(50) == 500

  describe "#_setPosition()", ->

    it "should emit position if changed", ->
      emittedPosition = null
      shutter.on "position", (position) ->
        emittedPosition = position
      shutter._setPosition("up")
      assert emittedPosition == "up"

    it "should do nothing when position did not change", ->
      shutter.on "position", (position) ->
        assert false
      shutter._position = "down"
      shutter._setPosition("down")

  describe "#moveByPercentage()", ->

    it "should use absolute value for calculating rolling time", ->
      shutter._calculateRollingTime = (actual) ->
        assert actual == 10
      shutter.moveByPercentage(-10)

    it "should call moveUp when percentage is higher than zero", ->
      movingUp = null
      shutter.moveUp = () ->
        movingUp = true
        Promise.resolve()
      shutter.moveDown = () ->
        assert false
      shutter.rollingTime = 1
      shutter.moveByPercentage(100).done()
      assert movingUp

    it "should call moveDown when percentage is lower than zero", ->
      movingDown = null
      shutter.moveUp = () ->
        assert false
      shutter.moveDown = () ->
        movingDown = true
        Promise.resolve()
      shutter.rollingTime = 1
      shutter.moveByPercentage(-100).done()
      assert movingDown

    it "should call stop when time is over", (finish) ->
      stopped = false
      shutter._calculateRollingTime = (percentage) ->
        return 100
      shutter.moveUp = () -> Promise.resolve()
      shutter.stop = () =>
        stopped = true
        return Promise.resolve()
      shutter.moveByPercentage(10).then(() ->
        assert stopped
        finish()
      ).done()
