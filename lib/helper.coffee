# Must be assert NOT 'cassert' because of  AssertionError class
assert = require 'assert'

module.exports.checkConfig = (moduleName, checker) ->
  try 
    checker()
  catch err
    if err instanceof assert.AssertionError
      msg = err.message.split " | "
      console.error "You have an error in your config file: #{msg[msg.length-1]}"
      console.error "In: #{moduleName}" if moduleName?
      console.error "details: #{msg[0]}" if msg.length is 2
      process.exit 1
    else 
    throw err
