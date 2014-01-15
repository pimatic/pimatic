fs = require("fs")

env =
  logger: require '../lib/logger'
  helper: require '../lib/helper'
  devices: require '../lib/devices'
  rules: require '../lib/rules'
  plugins: require '../lib/plugins'
  actions: require '../lib/actions'
  predicates: require '../lib/predicates'
  require: (args...) -> module.require args...

modules = fs.readdirSync ".."
plugins = (m for m in modules when m.match(/^pimatic-.*/)?)

for plugin in plugins 
  
  if process.env['PIMATIC_PLUGIN_TEST']? and process.env['PIMATIC_PLUGIN_TEST'] isnt plugin
    continue

  testFolder = "../#{plugin}/test"
  if fs.existsSync testFolder
    testFiles = fs.readdirSync testFolder
    for testFile in testFiles
      (require "../#{testFolder}/#{testFile}") env
    