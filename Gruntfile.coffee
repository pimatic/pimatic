module.exports = (grunt) ->

  path = require "path"
  # all node_modules:
  modules = require("fs").readdirSync ".."
  # just the pimatic-* modules:
  plugins = (module for module in modules when module.match(/^pimatic-.*/)?)

  # some realy dirty tricks:
  orgGrocPath = require("fs").existsSync './node_modules/grunt-groc/node_modules/groc'
  ownGrocPath = require("fs").existsSync './node_modules/groc'

  if orgGrocPath
    orgGroc = require './node_modules/grunt-groc/node_modules/groc'
    if ownGrocPath
      # Use our own groc implementation
      ownGroc = require './node_modules/groc'
      for name, prop of ownGroc
        orgGroc[name] = prop
    else
      grunt.log.writeln "Could not use own groc version. Not found!" 
  else
    unless ownGrocPath
      grunt.log.writeln "Could not use own groc version. Not found!" 

  grocTasks =
    pimatic:
      src: [
        "./config-schema.coffee"
        "./startup.coffee"
        "./lib/*.coffee"
      ]
      options: 
        root: "."
        out: "doc"
        "repository-url": "https://github.com/sweetpi/pimatic"
        style: 'pimatic'
          
  for plugin in plugins
    grocTasks[plugin] =
      src: [
        "../#{plugin}/README.md"
        "../#{plugin}/*.coffee"
      ]
      options: 
        root: "../#{plugin}"
        out: "../#{plugin}/doc"
        "repository-url": "https://github.com/sweetpi/pimatic"



  ftpTasks = {}
  for plugin in ["pimatic"].concat plugins 
    ftpTasks[plugin] =
      auth:
        host: "pimatic.org"
        port: 21
      authKey: 'pimatic.org'
      src: path.resolve __dirname, '..', plugin, "doc"
      dest: (if plugin is "pimatic" then "/pimatic/docs"
      else "/pimatic/docs/#{plugin}")

  # package.json files of plugins
  pluginPackageJson = ("../#{plugin}/package.json" for plugin in plugins)
  # and main package.json files
  bumpFiles = ["package.json"].concat pluginPackageJson

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
    groc: grocTasks

    "ftp-deploy": ftpTasks

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
    bump:
      options:
        files: bumpFiles
        updateConfigs: []
        commit: true
        commitMessage: "version %VERSION%"
        commitFiles: ["-a"] # '-a' for all files
        createTag: true
        tagName: "v%VERSION%"
        tagMessage: "version %VERSION%"
        push: true
        pushTo: "origin"
        gitDescribeOptions: "--tags --always --abbrev=1 --dirty=-d"


  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-groc"
  grunt.loadNpmTasks "grunt-ftp-deploy"
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
  grunt.registerTask "default", ["coffeelint", "mochaTest:test", "groc"]
  grunt.registerTask "test", ["coffeelint", "mochaTest:test"]
  grunt.registerTask "coverage", 
    ["blanket", "mochaTest:testBlanket", "mochaTest:coverage", "clean-coverage"]

  for plugin in plugins
    do (plugin) =>
      grunt.registerTask "setEnv:#{plugin}", =>
        process.env['PIMATIC_PLUGIN_TEST'] = plugin

      grunt.registerTask "test:#{plugin}", ["setEnv:#{plugin}", "mochaTest:testPlugin"]