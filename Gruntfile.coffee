module.exports = (grunt) ->

  path = require "path"
  # all node_modules:
  modules = require("fs").readdirSync ".."
  # just the pimatic-* modules:
  plugins = (module for module in modules when module.match(/^pimatic-.*/)?)

  # package.json files of plugins
  pluginPackageJson = ("../#{plugin}/package.json" for plugin in plugins)

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON "package.json"
    coffeelint:
      app: [
        "*.coffee"
        "../pimatic-*/*.coffee"
        "lib/**/*.coffee"
        "test/**/*.coffee"
      ]
      options:
        no_trailing_whitespace:
          level: "ignore"
        max_line_length:
          value: 100
        indentation:
          value: 2
          level: "error"
        no_unnecessary_fat_arrows:
          level: 'ignore'

    mochaTest:
      test:
        options:
          reporter: "spec"
          require: ['coffee-errors'] #needed for right line numbers in errors
        src: ["test/*"]
      testPlugin:
        options:
          reporter: "spec"
          require: ['coffee-errors'] #needed for right line numbers in errors
        src: ["test/plugins-test.coffee"]
      # blanket is used to record coverage
      testBlanket:
        options:
          reporter: "dot"
        src: ["test/*"]
      coverage:
        options:
          reporter: "html-cov"
          quiet: true
          captureFile: "coverage.html"
        src: ["test/*"]

  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-mocha-test"

  grunt.registerTask "blanket", =>
    blanket = require "blanket"

    blanket(
      pattern: (file) ->
        if file.match "pimatic/lib" then return true
        #if file.match "pimatic/node_modules" then return false
        withoutPrefix = file.replace(/.*\/node_modules\/pimatic/, "")
        return (not withoutPrefix.match 'node_modules') and (not withoutPrefix.match "/test/")
      loader: "./node-loaders/coffee-script"
    )

  grunt.registerTask "clean-coverage", =>
    fs = require "fs"
    path = require "path"

    replaceAll = (find, replace, str) => 
      escapeRegExp = (str) => str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")
      str.replace(new RegExp(escapeRegExp(find), 'g'), replace)

    file = "#{__dirname}/coverage.html"
    html = fs.readFileSync(file).toString()
    html = replaceAll path.dirname(__dirname), "", html
    fs.writeFileSync file, html

  # Default task(s).
  grunt.registerTask "default", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "test", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "coverage", 
    ["blanket", "mochaTest:testBlanket", "mochaTest:coverage", "clean-coverage"]

  for plugin in plugins
    do (plugin) =>
      grunt.registerTask "setEnv:#{plugin}", =>
        process.env['PIMATIC_PLUGIN_TEST'] = plugin

      grunt.registerTask "test:#{plugin}", ["setEnv:#{plugin}", "mochaTest:testPlugin"]