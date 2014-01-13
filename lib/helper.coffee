# Must be assert NOT 'cassert' because of  AssertionError class
assert = require 'assert'

module.exports.checkConfig = (env, moduleName, checker) ->
  try 
    checker()
  catch err
    if err instanceof assert.AssertionError
      msg = err.message.split " | "
      env.logger.error "You have an error in your config file: #{msg[msg.length-1]}"
      env.logger.error "In: #{moduleName}" if moduleName?
      env.logger.error "details: #{msg[0]}" if msg.length is 2
      process.exit 1
    else 
    throw err


module.exports.find = (array, key, value) =>
  assert Array.isArray array
  assert key?
  assert value?
  for e, i in array 
    if e[key] is value then return array[i]
  return null

module.exports.delete = (array, key, value) =>
  assert Array.isArray array
  assert key?
  assert value?
  for e, i in array 
    if e[key] is value
      array.splice i
      return true
  return false